# Suggestions for Codebase Improvement

## 1. Modularization
- **Issue**: Some functions in `Core.lua` and `Helpers.lua` are lengthy and handle multiple responsibilities.
- **Suggestion**: Split large functions into smaller, focused ones to improve readability and maintainability.

## 2. Error Handling
- **Issue**: Error handling is minimal, especially for API calls that may fail or return `nil`.
- **Suggestion**: Add robust error handling to gracefully manage edge cases (e.g., missing UI elements, API failures).

## 3. Documentation
- **Issue**: Inline comments are sparse, and there is no formal documentation for functions.
- **Suggestion**: Add detailed comments for each function, including parameters, return values, and usage examples.

## 4. Testing
- **Issue**: No automated tests are present, making it difficult to verify changes.
- **Suggestion**: Introduce unit tests for critical functions (e.g., text extraction, TTS queue management).

## 5. Performance
- **Issue**: Some functions (e.g., `GetReadableTextFromFrame`) iterate through many UI elements, which could impact performance.
- **Suggestion**: Optimize loops and reduce unnecessary iterations, especially in frequently called functions.

## 6. Configuration
- **Issue**: TTS settings (volume, rate, voice) are hardcoded or retrieved from the game settings without user overrides.
- **Suggestion**: Add a configuration UI or slash commands to allow users to customize TTS settings.

## 7. Localization
- **Issue**: The addon assumes English text and may not handle localized versions of the game well.
- **Suggestion**: Add support for localization to ensure compatibility with non-English game clients.

## 8. Code Duplication
- **Issue**: Some logic (e.g., text extraction) is duplicated across modules.
- **Suggestion**: Consolidate shared logic into `Helpers.lua` to reduce redundancy.

## 9. Event Management
- **Issue**: Event listeners are registered in multiple modules, which could lead to memory leaks if not cleaned up.
- **Suggestion**: Centralize event management to ensure proper cleanup and avoid duplicate listeners.

## 10. User Feedback
- **Issue**: There is no mechanism for users to provide feedback or report issues.
- **Suggestion**: Add a feedback system (e.g., slash command to submit logs or issues) to improve user support.
