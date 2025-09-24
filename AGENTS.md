# Agent Guidelines - R6 Objective Game

## Development Philosophy
- **Simplicity First:** Keep code modular and minimal — less code is better
- **Single Responsibility:** Each module/service handles one clear concern
- **Config-Driven:** Use centralized configuration over hardcoded values
- **Focused Changes:** Make minimal, targeted edits; avoid scope creep

## Code Standards
- **Error Handling:** Always validate inputs and handle edge cases
- **Memory Management:** Clean up connections and references properly
- **Performance:** Optimize for 60 FPS with minimal memory growth
- **Security:** Include rate limiting and anti-cheat measures

## Project Architecture
- **ServerScriptService:** Core game logic (rounds, objectives, lobby)
- **StarterPlayerScripts:** Client UI and input handling
- **ReplicatedStorage:** Shared configuration and networking
- **Modular Design:** Services communicate through events, not direct calls

## Testing Guidelines
- **Debug Logging:** Include comprehensive logging for troubleshooting
- **Edge Cases:** Test with varying player counts (1, 2, 8+ players)
- **Error Recovery:** Ensure graceful handling of disconnections and errors
- **Performance:** Monitor for memory leaks during extended play sessions

## When Making Changes
1. **Read existing code** to understand patterns and conventions
2. **Test thoroughly** with multiple players and scenarios
3. **Add debug logging** to help diagnose issues
4. **Clean up properly** - remove temporary debug code before committing
5. **Document changes** that affect gameplay or architecture

