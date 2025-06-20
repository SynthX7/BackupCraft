# 📦 Changelog – BackupCraft v1.6-test

## 🆕 Novidades
- 🔃 Reestruturação completa do sistema de backup.
- 📁 Nova estrutura de backup:
```
NomeDoMundo.7z/
├── advancements.txt ← Conteúdo do JSON com suas conquistas
└── World/ ← Dados reais do mundo
```
- 📊 Barra de progresso dinâmica e proporcional ao tamanho do backup.
- 👥 Detecção e restauração inteligente das conquistas do jogador (UUID mais recente recebe dados do antigo).
- 🔁 Novo comando `Restaurar conquistas` no menu para restaurar conquistas manualmente.

## ⚙️ Ajustes e Melhorias
- ✅ Compatibilidade com mundos que possuem espaço no nome.
- ✅ Detecção de ausência de arquivos de conquistas e resposta adequada.
- ✅ Compatibilidade com nomes de arquivos com acentos ou caracteres especiais.
- ✅ Menu mais limpo e funcional.
- ✅ `install.sh` remove versões antigas e informa mudanças da versão.

## 🟡 Pontos pendentes
- 💤 `bcauto` ainda não está implementado. A opção de backup automático foi removida temporariamente para melhoria.
- 🧪 Backup oculto não é criptografado, podendo ser acessado manualmente (melhoria futura).
- 📂 Ainda não implementado: restauração automática de conquistas a partir do `advancements.txt` contido no backup.

---

📌 Versão: **v1.6-test**
📅 Data de lançamento: 20/06/2025

> Esta é uma versão de testes. Use com atenção e sempre mantenha cópias de segurança manuais.
