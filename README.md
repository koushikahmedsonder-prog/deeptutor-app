# DeepTutor 📚

AI-powered tutor app for Class 9–11 students in Physics, Math & more.

## ✨ Features

### 🧠 AI Modules
- **Smart Solver** — Step-by-step problem solving with scaffolded math explanations
- **Question Generator** — Bloom's taxonomy-based quiz creation with mark schemes
- **Deep Research** — Academic-quality research reports with prerequisites
- **Idea Generator** — Brainstorm research ideas and co-write essays

### 📖 Study Tools
- **Study Planner** — AI-checked answers with correct/incorrect feedback
- **Notebook** — AI-powered notes with summarize, quiz, expand, connect
- **Knowledge Base** — Upload & query your own documents
- **Document Scanner** — Camera & file-based document capture

### ⚡ Performance
- Cached particle animations (RepaintBoundary)
- AutomaticKeepAlive chat bubbles
- Static const module lists — zero-allocation builds
- Optimized CustomPainter with pre-cached Paint objects

## 🏗️ Tech Stack
- **Framework:** Flutter (Dart)
- **State Management:** Riverpod
- **AI Backend:** Gemini, OpenAI, Claude, DeepSeek, Groq
- **Routing:** GoRouter
- **Storage:** Hive + SharedPreferences

## 🎨 Design System
- Dark glassmorphism theme with curated color palette
- Inter + Outfit typography via Google Fonts
- Reusable widgets: `GlassContainer`, `ActionChipButton`, `ToggleChip`
- Centralized markdown styling for consistent AI output rendering

## 🚀 Getting Started
```bash
cd deeptutor_app
flutter pub get
flutter run
```

## 📁 Project Structure
```
lib/
├── config/        # Theme, model config
├── providers/     # Riverpod state management
├── screens/       # All screen pages
├── services/      # API, storage, prompts, PDF export
└── widgets/       # Reusable UI components
```

## 🤖 AI Prompt Engineering
All prompts live in `lib/services/deeptutor_prompts.dart` and enforce:
- Structured markdown output (headers, tables, blockquotes)
- Class-level adaptive teaching (9/10/11)
- Bloom's taxonomy question generation
- Spaced-repetition study hints
- Step-by-step math scaffolding