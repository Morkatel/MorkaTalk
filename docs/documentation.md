# MorkaUI Documentation

## Project Overview
MorkaUI is a World of Warcraft addon designed to enhance accessibility by providing text-to-speech (TTS) functionality for various in-game UI elements. It reads out quests, NPC dialogues, auction house items, merchant prices, and error messages, making the game more accessible for visually impaired players.

## Directory Structure
```
MorkaUI/
├── .vscode/
├── AuctionHouse.lua
├── Core.lua
├── ErrorPopup.lua
├── Helpers.lua
├── MailBox.lua
├── MorkaUI.toc
├── NpcChat.lua
└── QuestFrame.lua
```

## Key Components

### Core.lua
- **Purpose**: Central module for TTS functionality.
- **Responsibilities**:
  - Manages the TTS queue and speech timing.
  - Handles reading text from various sources (hovered buttons, tooltips, quests, etc.).
  - Provides functions to skip lines, stop speaking, and control speech.
  - Exposes functions for other modules to use.

### Helpers.lua
- **Purpose**: Utility functions for TTS and UI interaction.
- **Responsibilities**:
  - Extracts readable text from UI frames.
  - Provides logging and debugging utilities.
  - Handles TTS settings (volume, rate, voice).
  - Estimates speech duration for timing.
  - Retrieves text from hovered UI elements, merchant prices, and auction house items.

### AuctionHouse.lua
- **Purpose**: Handles TTS for auction house interactions.
- **Responsibilities**:
  - Tracks hovered auction house items (buy, sell, own).
  - Reads out item details (name, price, quantity) when hovered.

### QuestFrame.lua
- **Purpose**: Manages TTS for quest-related UI elements.
- **Responsibilities**:
  - Extracts and reads quest text (title, description, objectives, rewards).
  - Checks if a quest is available for reading.

### MailBox.lua
- **Purpose**: Provides TTS for mailbox interactions.
- **Responsibilities**:
  - Debugs mailbox UI elements (currently in development).
  - Extracts text from mail items when hovered.

### ErrorPopup.lua
- **Purpose**: Reads out error messages.
- **Responsibilities**:
  - Listens for UI error messages and reads them aloud.
  - Ensures errors are announced even during other speech.

### NpcChat.lua
- **Purpose**: Handles TTS for NPC dialogues.
- **Responsibilities**:
  - Listens for NPC chat events (say, yell, emote, party).
  - Reads out NPC messages in real-time.

### MorkaUI.toc
- **Purpose**: Addon manifest file.
- **Responsibilities**:
  - Lists all Lua files to be loaded by the game.
  - Provides metadata (title, author, version).

## Dependencies
- **World of Warcraft API**: Uses Blizzard's API for UI interactions, TTS, and event handling.
- **C_VoiceChat**: For TTS functionality.
- **C_Timer**: For managing speech timing and delays.
- **C_AuctionHouse**: For auction house data retrieval.
- **C_MerchantFrame**: For merchant price information.

## Flow Summary
1. **Initialization**: The addon loads all modules listed in `MorkaUI.toc`.
2. **Event Handling**: Modules register for specific events (e.g., `CHAT_MSG_MONSTER_SAY`, `UI_ERROR_MESSAGE`).
3. **Text Extraction**: When an event occurs or a UI element is hovered, the relevant module extracts readable text.
4. **TTS Queue**: Extracted text is added to the TTS queue in `Core.lua`.
5. **Speech**: The TTS system reads the queued text aloud, with timing controlled by `C_Timer`.
6. **User Control**: Players can skip lines or stop speech using keyboard shortcuts (e.g., LShift, LAlt).

## Conclusion
MorkaUI is a powerful accessibility tool for World of Warcraft, but there are several areas where improvements can be made. Focus on modularization, error handling, and performance optimization to enhance maintainability and user experience.