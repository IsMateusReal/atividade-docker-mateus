# Atividade Docker — Mateus

As três partes e o bônus de Compose foram executados, com evidências em `evidencias/`.
A persistência preservou 11 linhas antigas, passando a 13 após recriar o container.
Sem volume, o acesso antigo desapareceu. O site original foi preservado na Versão 2. O roteiro reproduz temporariamente a
Versão 1 para registrar a alteração pelo bind mount e restaura o HTML original,
inclusive se ocorrer uma falha.

## Executar

Na raiz desta pasta, em um terminal com acesso ao Docker:

```bash
bash comandos.sh
```

Se aparecer `permission denied` no socket do Docker, use um terminal que já tenha
acesso ao serviço ou execute `sudo bash comandos.sh` localmente e autentique-se.
O script verifica esse acesso antes de alterar os arquivos. Ele reaproveita `web-bind` se usar `nginx:alpine`, porta 8080 e esta pasta
`site/` montada como somente leitura. Os demais containers e o volume da atividade
continuam protegidos contra sobrescrita.
Se algum existir, confira seu conteúdo antes de decidir removê-lo. Em caso de falha
parcial, preserve as evidências e confira os recursos antes de repetir.

As saídas e os comandos efetivamente executados ficam em `evidencias/execucao-*.txt`,
com usuário e máquina. As pausas orientam os prints do navegador e do terminal.
As imagens precisam ser capturadas manualmente e ter os nomes indicados no roteiro.
Não confunda o roteiro preparado com um registro de execução já concluída.

## Conferir antes de entregar

- Prints Parte 1: página Versão 1 e Versão 2, navegação em `/sobre.html`, curl, erro de escrita e mounts.
- Prints Parte 2: build, imagem, `/saude`, log com 200 e 404, volume inspect.
- Prints Parte 3: contagem antes/depois, remoção e recriação, leitura pelo Alpine,
  `docker ps`, log com as duas origens e comparação sem volume.
- Todo print de terminal deve mostrar usuário ou máquina; as linhas de execução incluem ambos.
- As seis respostas de `RELATORIO.md` registram os resultados observados e referenciam as evidências.
- O bônus está comprovado em `bonus-01-compose-up.png` e `bonus-02-compose-down.png`.
  Para reproduzi-lo, siga os comandos Compose no relatório.
- Para repetir do zero, a limpeza indicada no final de `comandos.sh` é manual:
  remover `logs-web` destrói os logs. Salve as evidências antes.

Após a validação, compacte a pasta sem as pastas de metadados do ambiente:

```bash
cd ..
zip -r atividade-docker-mateus.zip atividade-docker-mateus \
  -x '*/.git/*' '*/.agents/*' '*/.codex/*' '*/.aws/*'
```

Não inclua imagem Docker `.tar` nem arquivos internos do volume.
