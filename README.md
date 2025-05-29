# BackupCraft

BackupCraft é um programa de backup leve e rápido para mundos do Minecraft. Com ele, você pode criar cópias completas dos seus mundos sem precisar sair do jogo, tudo através do terminal.

> ⚠️ **Este programa é feito para Linux**. Para rodá-lo, é necessário dar permissão de execução:
> ```bash
> chmod +x backupcraft.sh
> ```

## Como usar
1. Coloque o script `backupcraft.sh` em qualquer diretório de sua preferência, é recomendável na pasta principal do seu usuário (/home/seunome).
2. Abra o terminal e execute o script:
   ```bash
   ./backupcraft.sh
   ```
3. Escolha uma das opções disponíveis digitando o número associado:
   - [1] Criar Backup
   - [2] Restaurar Backup
   - [3] Configurações
   - [4] Sair

## Por que usar o BackupCraft ao invés do sistema nativo do Minecraft?

O Minecraft possui sim uma função de backup, mas ela é limitada e mais lenta. Veja o que o BackupCraft faz melhor:

### ✅ Backup instantâneo, mesmo com o jogo aberto
- O sistema nativo **só permite backup no menu principal**.
- Com o BackupCraft, você pode fazer backup **mesmo dentro do mundo**, sem precisar sair ou esperar o jogo reiniciar.

### ✅ Mais rápido e leve
- Em computadores fracos, abrir o Minecraft só pra fazer backup **demora demais**.
- O BackupCraft roda direto no terminal e **não consome quase nada de recursos**.

### ✅ Backups separados por data
- O modo de múltiplos backups cria **várias versões organizadas por data**, permitindo que você volte no tempo facilmente.

### ⚠️ Desvantagem atual
- Precisa saber o mínimo de como usar o terminal.
- Mas isso será resolvido em breve com uma **interface gráfica em Python**, que tornará o uso simples até pra quem nunca usou Linux antes.

# ⚙️ Configurações do Script de Backup

Para entrar nas configurações, basta digitar "3" no menu principal e depois `Enter`.

Este script utiliza um arquivo `backup_config.txt` para personalizar seu comportamento. Abaixo está a explicação de cada configuração e o que acontece ao ativá-la ou desativá-la.

---

## Parâmetros disponíveis

| Configuração              | Opções            | Descrição                                                                 |
|--------------------------|-------------------|---------------------------------------------------------------------------|
| `MULTIPLE_BACKUPS`       | `true` ou `false` | `true`: Cria um novo backup com data/hora a cada vez.<br>`false`: Mantém apenas um backup por mundo, sobrescrevendo o anterior. |
| `ENABLE_HIDDEN_BACKUP`   | `true` ou `false` | `true`: Cria uma cópia oculta de segurança na pasta `.backup_escondido`.<br>`false`: Não cria essa cópia. |
| `USE_ADVANCED_SORT`      | `true` ou `false` | `true`: Usa uma ordenação mais avançada e intuitiva dos backups.<br>`false`: Usa ordenação alfabética simples. |
| `DELETE_EMPTY_BACKUPS`   | `true` ou `false` | `true`: Apaga backups vazios ou corrompidos automaticamente.<br>`false`: Mantém arquivos vazios no disco. |
| `SHOW_BACKUP_COUNT`      | `true` ou `false` | `true`: Mostra quantos backups existem por mundo antes de restaurar.<br>`false`: Não mostra essa informação. |
| `SHOW_RESTORE_COUNT`     | `true` ou `false` | `true`: Exibe quantas restaurações foram feitas com sucesso.<br>`false`: Não exibe esse contador. |
| `ALLOW_MANUAL_RESTORE`   | `true` ou `false` | `true`: Permite escolher manualmente qual backup restaurar.<br>`false`: Restaura automaticamente o mais recente. |

---

## Observações

- O arquivo `backup_config.txt` será criado automaticamente na primeira execução do script, com valores padrão.
- Todas as opções devem ser escritas em minúsculas (`true` ou `false`), sem aspas.



---

Com o BackupCraft, você economiza tempo, ganha segurança e ainda mantém seu mundo protegido mesmo quando o jogo não ajuda. Ideal pra quem gosta de testar comandos, mods ou construir à vontade sem medo de errar.

---

💡 **Dica:** use antes de tentar algo arriscado no jogo. Evita dor de cabeça. 😉
