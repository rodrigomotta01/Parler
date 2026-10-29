<div align="center">

# Parler 🥐

**Aplicativo moderno de imersão e aprendizado de francês com repetição espaçada (FSRS), leitor bilíngue de e-books com sincronização palavra por palavra estilo Spotify Lyrics e gramática prática.**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)](https://dart.dev)
[![FSRS](https://img.shields.io/badge/Algorithm-FSRS%20v4.5-8B5CF6)](https://github.com/open-spaced-repetition/fsrs4dart)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://www.android.com)
[![Offline First](https://img.shields.io/badge/Storage-100%25%20Offline%20(SQLite)-003B57?logo=sqlite)](https://sqlite.org)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

</div>

---

## 📖 Visão Geral

O **Parler** foi projetado para quem deseja dominar o francês real através de **imersão compreensível e repetição espaçada científica**, sem distrações ou sobrecarga.

Inspirado na estética limpa do **macOS Sonoma** e do **Raycast**, o app adota superfícies translúcidas com efeito *glassmorphism*, bordas ultrafinas, paleta pastel suave e contraste cuidadoso para proporcionar longas sessões de leitura e estudo sem fadiga visual.

---

## ✨ Principais Funcionalidades

### 🧠 1. Revisão Inteligente com FSRS (Spaced Repetition)
- **Algoritmo FSRS v4.5**: substitui o antigo SM-2 do Anki por curvas de esquecimento modernas de maior precisão.
- **4 Graus de Avaliação**: *De novo* (Again), *Difícil* (Hard), *Bom* (Good) e *Fácil* (Easy).
- **Tradução em Português (PT-BR)**: cada lema é apresentado com sua classe gramatical, tradução natural para o português e exemplos de uso reais.
- **Destaque Visual de Palavra e Tradução**: a palavra estudada e sua tradução são destacadas dinamicamente dentro da frase de exemplo.
- **Áudio Nativo (TTS)**: pronúncia em velocidade normal e lenta para treino do aparelho fonador.

### 📚 2. Leitor Bilíngue com Áudio e *Spotify Lyrics*
- **Suporte a E-books (EPUB e PDF)**: carregue os contos clássicos inclusos (*Le Petit Prince*, *Les Misérables*, *Contes de Maupassant*) ou **importe seus próprios arquivos** (.epub e .pdf).
- **Extração e Exibição de Imagens**: ilustrações embutidas nos livros são extraídas e exibidas harmoniosamente no fluxo de leitura.
- **Tradução Intercalada Frase a Frase**: tradução em PT-BR exibida imediatamente abaixo de cada frase francesa no parágrafo — sem grandes blocos acumulados no rodapé.
- **Destaque Palavra por Palavra em Tempo Real (*Spotify Style*)**: durante a reprodução do áudio, a palavra exata sendo falada é destacada com cor mais contrastante e peso semântico, acompanhando o ritmo da narração.
- **Retomada Precisa na Palavra (`word_idx`)**: ao pausar para ler com calma ou consultar um termo, o áudio é salvo e recomeça **exatamente daquela palavra**, e não do início do parágrafo.
- **Rolagem Automática Suave (*Auto-Scroll*)**: o texto acompanha automaticamente a reprodução do áudio, mantendo a frase corrente sempre visível no terço superior da tela.
- **Contador Real de Páginas (`Página X de Y`)**: cálculo dinâmico baseado em densidade de palavras para acompanhar seu progresso real de leitura.
- **Dicionário Raio-X do Capítulo**: toque em qualquer palavra desconhecida para abrir instantaneamente sua definição completa, sem perder seu lugar na leitura.

### 💡 3. Gramática Básica Prática & Exercícios Interativos
Módulo focado nas principais dificuldades de falantes de português aprendendo francês:
1. **Ordem da Frase e a Negação (`ne ... pas`)**: por que o sujeito é obrigatório e como estruturar negações (incluindo `n'` antes de vogal).
2. **Como Fazer Perguntas**: entonação do dia a dia, a fórmula coringa `Est-ce que` e interrogativos (`Où`, `Quand`, `Pourquoi`, `Comment`, `Qu’est-ce que`).
3. **Os 4 Verbos Pilares**: conjugações completas e peculiaridades de *être*, *avoir* (idade e sensações como *faim, soif, peur*), *aller* e *faire*.
4. **Conjugação Regular (-ER, -IR, -RE) e o Som Mudo**: o segredo das terminações mudas (`-e, -es, -ent` que soam idênticas).
5. **Preposições Essenciais e Contrações**: cidades (`à`), países femininos (`en`) e masculinos (`au`), pessoas/lugares (`chez`), e contrações obrigatórias (`au`, `du`, `aux`, `des`).
6. **Tempos Verbais Simples**: domínio do *Présent*, *Passé Composé* (auxiliar + particípio) e *Futur Proche* (*aller* + infinitivo).
7. **Artigos e Partitivos**: uso correto de `du`, `de la`, `des` e a regra de ouro do `pas de` na negativa.
- **Exercícios Interativos**:
  - *Construtor de Frases*: organize palavras embaralhadas na ordem sintática correta.
  - *Identificador de Tempo Verbal*: reconheça instantaneamente o tempo da sentença.
  - *Completar Lacuna*: pratique preposições, verbos e contrações com feedback explicativo imediato.

### 📅 4. Atividade Diária Estilo *GitHub Contributions*
- **Heatmap Anual/Semanal**: grade diária inspirada no painel de contribuições do GitHub, destacando dias de estudo e cumprimento da meta diária.
- **Meta Diária Personalizável**: configure sua meta de revisões ou minutos de áudio diretamente na tela de Ajustes.
- **Inspeção de Dias**: toque em qualquer dia do mapa para conferir as revisões realizadas e tempo de escuta registrado.

### 🎧 5. Treino de Áudio & Compreensão Oral
- **Ditado Auditivo (*Dictation*)**: ouça e digite a frase, recebendo análise caractere por caractere das correções necessárias.
- **Quiz de Escuta**: exercite a capacidade de distinguir palavras de sonoridade próxima (*homófonos*) em francês.
- **Cloze de Frases**: complete as palavras faltantes com base na fala nativa.

---

## 🎨 Design System

O projeto obedece a regras estritas de design system documentadas em `lib/ui.dart`:

| Token | Cor | Finalidade |
|---|---|---|
| `T.bg` | `#FAF8F5` | Fundo principal quente e suave |
| `T.surface` | `#FFFFFF` @ 72% | Superfície translúcida com desfoque (*Blur 20*) |
| `T.lavender`| `#C9C3F5` | Cor primária / Ações de SRS |
| `T.peach` | `#FFD6BF` | Indicador de Sequência (*Streak* 🔥) |
| `T.mint` | `#BFEBD9` | Sucesso / Avaliação Fácil / Metas concluídas |
| `T.sky` | `#C2DDF7` | Áudio / Leitura / Ouvir |
| `T.butter` | `#FBEDB5` | Destaques gramaticais e chamadas |
| `T.rose` | `#F7C6CF` | Erro / Avaliação Repetir (*Again*) |

---

## 🛠️ Tecnologias Utilizadas

- **Framework**: [Flutter](https://flutter.dev) (Dart 3.x)
- **Banco de Dados**: SQLite via [`sqflite`](https://pub.dev/packages/sqflite)
- **Áudio e TTS**: [`flutter_tts`](https://pub.dev/packages/flutter_tts)
- **Leitor de Documentos**: [`syncfusion_flutter_pdf`](https://pub.dev/packages/syncfusion_flutter_pdf) e [`archive`](https://pub.dev/packages/archive) (EPUB)
- **Notificações**: [`flutter_local_notifications`](https://pub.dev/packages/flutter_local_notifications) & [`flutter_timezone`](https://pub.dev/packages/flutter_timezone)
- **Ícones**: `CupertinoIcons`

---

## 🚀 Como Executar o Projeto

### Pré-requisitos
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (versão 3.22 ou superior)
- [Android Studio](https://developer.android.com/studio) com Android SDK configurado
- Dispositivo Android físico ou emulador com suporte a TTS

### Instalação

1. Clone o repositório:
```bash
git clone https://github.com/SEU_USUARIO/parler.git
cd parler
```

2. Instale as dependências:
```bash
flutter pub get
```

3. Execute a suíte de testes unitários:
```bash
flutter test
```

4. Verifique a análise estática:
```bash
dart analyze
```

5. Execute no dispositivo/emulador:
```bash
flutter run
```

6. Gerar o APK Release:
```bash
flutter build apk --release
```
O APK final será gerado em:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 🔒 Privacidade e Filosofia Offline

- **100% Offline**: o app funciona sem conexão com a internet.
- **Zero Rastreamento**: nenhum dado do usuário, progresso ou biblioteca de livros é enviado para serviços na nuvem.
- **Sem Anúncios**: interface limpa e focada exclusivamente no aprendizado.

---

## 📜 Licença

Distribuído sob a licença MIT. Consulte `LICENSE` para mais informações.
