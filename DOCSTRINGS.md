# Docstrings — Quick Guide (42)

Recommended tool:
- VS Code extension: autoDocstring
```bash
code --install-extension njpwerner.autodocstring
```

Usage:
1. Place cursor inside a function
2. Type """ and press Enter
3. Fill the generated template

Docstring format:
- Short summary
- Args
- Returns

Example:

def add(a: int, b: int) -> int:
    """
    Add two integers.

    Args:
        a (int): First integer.
        b (int): Second integer.

    Returns:
        int: Sum of a and b.
    """
