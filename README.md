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

Por exemplo: se quiser criar um backup, terá que digitar `1`. Se quiser restaurar um backup, terá que digitar `2`. E por aí vai.

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

# ⚙️ Explicação das configurações do programa

Para entrar nas configurações, basta digitar `3` no menu principal e depois `Enter`.

---

1. **Backups versionados**  
   - ✅ **Ativado:** Mantém várias versões do backup com datas para restaurar estados anteriores.  
   - ❌ **Desativado:** Só mantém o backup mais recente, substituindo versões anteriores.

2. **Substituir mundo ao restaurar**  
   - ✅ **Ativado:** O mundo atual é substituído automaticamente pelo backup restaurado.  
   - ❌ **Desativado:** O backup é restaurado com um sufixo "(BackupCraft)", sem substituir o mundo atual.

3. **Ignorar mundos restaurados (com sufixo '(BackupCraft)')**  
   - ✅ **Ativado:** Ignora mundos com sufixo "(BackupCraft)" que estão dentro da pasta "saves".  
   - ❌ **Desativado:** Considera todos os mundos, incluindo os já restaurados.

4. **Backup oculto extra**  
   - ✅ **Ativado:** Cria um backup extra em local oculto para maior segurança.  
   - ❌ **Desativado:** Apenas o backup principal é criado, sem cópia adicional.

---

## Observações

- O arquivo `backup_config.txt` será criado automaticamente na primeira execução do script, com valores padrões (só altere se souber o que está fazendo).
- Todas as opções devem ser escritas em minúsculas (`true` ou `false`), sem aspas.



---

Com o BackupCraft, você economiza tempo, ganha segurança e ainda mantém seu mundo protegido mesmo quando o jogo não ajuda. Ideal pra quem gosta de testar comandos, mods ou construir à vontade sem medo de errar.

---

💡 **Dica:** use antes de tentar algo arriscado no jogo. Evita dor de cabeça. 😉
