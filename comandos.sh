#!/usr/bin/env bash
set -Eeuo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
for ferramenta in docker curl python3; do command -v "$ferramenta" >/dev/null; done
docker info >/dev/null
# Reaproveita somente um web-bind compatível, sem apagar o trabalho anterior.
reusar_bind=false
if dados_bind=$(docker container inspect web-bind 2>/dev/null); then
  printf '%s' "$dados_bind" | python3 -c '
import json, sys
from pathlib import Path
c = json.load(sys.stdin)[0]
mounts = c.get("Mounts", [])
assert any(m.get("Type") == "bind"
           and Path(m.get("Source", "")).resolve() == Path("site").resolve()
           and m.get("Destination") == "/usr/share/nginx/html"
           and m.get("RW") is False for m in mounts), "web-bind tem montagem incompatível; preserve-o e confira docker inspect web-bind"
assert c["Config"]["Image"] == "nginx:alpine", "Imagem de web-bind incompatível"
ports = c["HostConfig"].get("PortBindings") or {}
assert any(p.get("HostPort") == "8080" for p in (ports.get("80/tcp") or [])), "Porta de web-bind incompatível"
'
  reusar_bind=true
fi
# Outros recursos continuam protegidos contra sobrescrita.
for nome in web-vol web-vol2 web-sem-vol; do
  if docker container inspect "$nome" >/dev/null 2>&1; then
    echo "Container $nome já existe. Confira e remova-o antes de começar." >&2; exit 1
  fi
done
if docker volume inspect logs-web >/dev/null 2>&1; then
  echo 'logs-web já existe. Preserve os dados ou remova o volume explicitamente antes de começar.' >&2; exit 1
fi
exec > >(tee "evidencias/execucao-$(date +%Y%m%d-%H%M%S).txt") 2>&1
PS4='+ $(id -un)@$(hostname):${LINENO}: '
set -x
pausa() { if [[ -t 0 ]]; then read -r -p "$1 Pressione Enter para continuar. "; fi; }
espera() {
  for tentativa in {1..30}; do
    if curl -fsS "$1" -o /dev/null; then return 0; fi
    sleep 1
  done
  return 1
}
# Parte 1
# Guarda o HTML original e o restaura mesmo se algum comando falhar.
original=$(mktemp)
cp site/index.html "$original"
trap 'cp "$original" site/index.html; rm -f "$original"' EXIT
python3 - <<'PY'
from pathlib import Path
p = Path('site/index.html')
s = p.read_text()
assert 'Versão 2' in s, 'Esperado o HTML original na Versão 2'
p.write_text(s.replace('Versão 2', 'Versão 1'))
PY
docker version
if "$reusar_bind"; then
  if [[ $(docker inspect web-bind --format '{{.State.Running}}') != true ]]; then
    docker start web-bind
  fi
else
  docker run -d --name web-bind -p 8080:80 -v "$(pwd)/site:/usr/share/nginx/html:ro" nginx:alpine
fi
espera http://localhost:8080
curl -fsS http://localhost:8080/
curl -fsS http://localhost:8080/sobre.html
curl -fsS http://localhost:8080/ | grep 'Versão 1'
inicio=$(docker inspect web-bind --format '{{.State.StartedAt}}')
pausa 'Abra localhost:8080 e salve parte1-01-pagina-antes.png em evidencias/.'
cp "$original" site/index.html
curl -fsS http://localhost:8080/ | grep 'Versão 2'
test "$inicio" = "$(docker inspect web-bind --format '{{.State.StartedAt}}')"
pausa 'Recarregue a página e salve parte1-02-pagina-depois.png; visite também /sobre.html.'
if erro=$(docker exec web-bind touch /usr/share/nginx/html/teste.txt 2>&1); then
  echo 'ERRO: escrita deveria ter sido bloqueada'; exit 1
fi
printf '%s\n' "$erro"
grep -qi 'Read-only file system' <<< "$erro"
docker inspect web-bind --format '{{json .Mounts}}'
pausa 'Capture o terminal identificado com o erro e os mounts (parte1-03-terminal.png).'
# Parte 2
docker build -t meu-web:1.0 .
docker images meu-web
docker volume create logs-web
docker run -d --name web-vol -p 8081:80 -v logs-web:/var/log/nginx meu-web:1.0
espera http://localhost:8081/saude
curl -fsS http://localhost:8081/
curl -fsS http://localhost:8081/sobre.html
curl -fsS http://localhost:8081/saude | grep -Fx 'ok - 20231003300546'
test "$(curl -sS -o /dev/null -w '%{http_code}' http://localhost:8081/inexistente)" = 404
curl -fsS 'http://localhost:8081/saude?parte2=quinta'
docker exec web-vol cat /var/log/nginx/acessos.log
docker volume inspect logs-web
docker volume inspect logs-web --format '{{.Mountpoint}}' > evidencias/volume-mountpoint.txt
pausa 'Capture build, imagem, saude, log e volume inspect (prints parte2-*).'
# Parte 3
# nginx faz flush a cada requisição (log sem buffer configurado).
docker exec web-vol cat /var/log/nginx/acessos.log > evidencias/parte3-log-antes.txt
antes=$(docker exec web-vol sh -c 'wc -l < /var/log/nginx/acessos.log')
id_antigo=$(docker inspect web-vol --format '{{.Id}}')
docker rm -f web-vol
docker volume ls
docker volume inspect logs-web
docker run -d --name web-vol -p 8081:80 -v logs-web:/var/log/nginx meu-web:1.0
espera http://localhost:8081/saude
curl -fsS 'http://localhost:8081/saude?apos=recriacao'
test "$id_antigo" != "$(docker inspect web-vol --format '{{.Id}}')"
depois=$(docker exec web-vol sh -c 'wc -l < /var/log/nginx/acessos.log')
test "$depois" -gt "$antes"
docker exec web-vol cat /var/log/nginx/acessos.log > evidencias/parte3-log-depois.txt
python3 - <<'PY'
from pathlib import Path
antes = Path('evidencias/parte3-log-antes.txt').read_bytes()
depois = Path('evidencias/parte3-log-depois.txt').read_bytes()
assert depois.startswith(antes), 'O log antigo não foi preservado integralmente'
print('Persistência confirmada: log antigo preservado e novas linhas acrescentadas.')
PY
printf 'Linhas antes: %s; depois: %s\n' "$antes" "$depois"
docker run --rm -v logs-web:/dados:ro alpine tail -n 20 /dados/acessos.log
docker run -d --name web-vol2 -p 8082:80 -v logs-web:/var/log/nginx meu-web:1.0
espera http://localhost:8082/saude
# A porta publicada não aparece no formato padrão do access_log: a query identifica a origem.
curl -fsS 'http://localhost:8081/saude?origem=8081'
curl -fsS 'http://localhost:8082/saude?origem=8082'
docker exec web-vol cat /var/log/nginx/acessos.log > evidencias/parte3-log-compartilhado.txt
grep 'origem=8081' evidencias/parte3-log-compartilhado.txt
grep 'origem=8082' evidencias/parte3-log-compartilhado.txt
docker ps
docker run -d --name web-sem-vol -p 8083:80 meu-web:1.0
espera http://localhost:8083/saude
curl -fsS 'http://localhost:8083/saude?temporario=antes'
docker inspect web-sem-vol --format '{{json .Mounts}}'
docker exec web-sem-vol cat /var/log/nginx/acessos.log > evidencias/parte3-sem-volume-antes.txt
docker rm -f web-sem-vol
# Recria sem volume e verifica que o marcador antigo desapareceu.
docker run -d --name web-sem-vol -p 8083:80 meu-web:1.0
espera http://localhost:8083/saude
docker exec web-sem-vol cat /var/log/nginx/acessos.log > evidencias/parte3-sem-volume-depois.txt
if grep -q 'temporario=antes' evidencias/parte3-sem-volume-depois.txt; then
  echo 'ERRO: marcador antigo encontrado sem volume'; exit 1
fi
docker rm -f web-sem-vol
pausa 'Capture as provas de persistência, portas e comparação sem volume (parte3-*).'
echo 'Roteiro concluído. Revise os prints e complete o relatório com os resultados reais.'
# Limpeza opcional, depois de preservar as evidências (não executada):
# docker rm -f web-bind web-vol web-vol2
# docker volume rm logs-web
