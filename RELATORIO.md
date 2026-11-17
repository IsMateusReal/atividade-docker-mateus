# Servidor web com Docker e volumes

Nome: Mateus Afonso Miranda de Oliveira  
Matrícula: 20231003300546  
Turma: CIC1001 A03

As Partes 1, 2 e 3 e o bônus foram executados no Ubuntu. Os prints e os
arquivos de log usados nas respostas estão na pasta `evidencias/`.

## 1. Bind mount e volume nomeado

No bind mount, escolho uma pasta do computador, neste caso `site/`, que aparece dentro do container.
No volume nomeado, o Docker gerencia o armazenamento identificado como `logs-web`.
Usaria bind mount para editar o HTML durante o desenvolvimento e volume para guardar logs persistentes.
O print `parte1-03-terminal.png` mostra o bind da pasta `site/`; `parte2-05-containers-volume-inspect.png` identifica o volume gerenciado.

## 2. Montagem somente leitura

O `:ro` permite ao Nginx ler o site, mas impede o container de escrever nessa montagem.
O `touch` retornou `Read-only file system`, pois o destino foi montado como somente leitura.
Isso protege os arquivos do host de alterações feitas por processos dentro do container.
O erro e o campo `"RW":false` aparecem em `parte1-03-terminal.png`.

## 3. Logs com e sem volume

Sem volume, `acessos.log` fica na camada gravável exclusiva do container e desaparece quando ele é removido.
Recriar o container a partir da imagem gera outra camada gravável, sem as requisições antigas.
Com `logs-web`, as 11 linhas antigas foram preservadas e o log passou a ter 13 linhas após a recriação.
Os arquivos `parte3-log-antes.txt` e `parte3-log-depois.txt` mostram essa preservação; em `parte3-sem-volume-*.txt`, o marcador antigo desapareceu.

## 4. Local do volume e remoção

O `Mountpoint` observado foi `/var/lib/docker/volumes/logs-web/_data`.
Esse caminho está em `evidencias/volume-mountpoint.txt` e no print `parte2-05-containers-volume-inspect.png`.
`docker rm -f` remove o container, mas mantém o volume nomeado e seus dados.
`docker volume rm logs-web` apaga esse volume quando nenhum container o estiver usando.

## 5. Atualização do site

Na Parte 1, o Nginx lê a pasta do host, e a mudança de Versão 1 para Versão 2 apareceu ao recarregar a página, sem recriar o container.
Na Parte 2, o `COPY` incorpora o HTML na imagem; uma nova versão exige build e recriação dos containers.
Por exemplo: `docker build -t meu-web:1.1 .`, seguido de novos containers usando essa tag e o mesmo volume.
O bind mount facilita o desenvolvimento; uma imagem versionada facilita uma publicação reproduzível em produção.
Os prints `parte1-01-pagina-antes.jpg`, `parte1-02-pagina-depois.jpg` e `parte2-01-build.png` registram essas etapas.

## 6. Portas dos containers

Cada container tem seu próprio ambiente de rede e pode escutar na porta interna 80.
O mapeamento `-p 8081:80` encaminha a porta 8081 do host para o primeiro container na rede bridge.
Já `-p 8082:80` encaminha a porta 8082 para o segundo, sem disputar a mesma porta publicada no host.
O print `parte3-07-volume-compartilhado.png` mostra os dois containers e as queries `origem=8081` e `origem=8082` no mesmo log.

## Bônus: Docker Compose

O `compose.yaml` define dois serviços com a imagem própria, portas 8081 e 8082 e o mesmo volume `logs-web`.
Depois de registrar as evidências do roteiro, libere essas portas removendo somente os containers da atividade:

```bash
# Remova os containers manuais se ainda estiverem usando as portas:
# docker rm -f web-bind web-vol web-vol2 web-sem-vol
docker compose config
docker compose up -d --build
curl http://localhost:8081/saude
curl http://localhost:8082/saude
docker compose ps
docker compose down
```

O `down` mantém o volume. Não use `down -v` se precisar preservar os logs.
O teste foi concluído: os dois serviços responderam `200 OK` com a matrícula, e o `down` removeu os containers e a rede, mantendo `logs-web`. As evidências são `bonus-01-compose-up.png` e `bonus-02-compose-down.png`.
