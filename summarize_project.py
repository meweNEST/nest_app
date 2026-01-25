import os

# --- Configuration ---
# The root directory of your Flutter project. '.' means the current directory.
project_root = '.'

# List of directories to completely ignore.
# We ignore platform-specific folders, build artifacts, and IDE settings to save tokens.
ignore_dirs = {
    'ios', 'android', 'web', 'windows', 'macos', 'linux', # Platform folders
    'build', '.dart_tool', '.git', '.idea', '.vscode', '__pycache__' # Build/tooling folders
}

# List of file extensions to include in the content summary.
include_extensions = {'.dart', '.yaml', '.md'}

# --- Script ---

final_summary = []

# Part 1: Generate the directory and file tree structure
final_summary.append("--- PROJECT STRUCTURE ---\n")

tree_output = []
for root, dirs, files in os.walk(project_root):
    # Modify dirs in-place to prevent os.walk from descending into ignored directories
    dirs[:] = [d for d in dirs if d not in ignore_dirs]

    level = root.replace(project_root, '').count(os.sep)
    indent = ' ' * 4 * (level)
    
    # Don't print the root folder name ('.')
    if root != project_root:
        tree_output.append(f"{indent}{os.path.basename(root)}/")
    
    sub_indent = ' ' * 4 * (level + 1)
    for f in sorted(files):
        # Only show files that are not in hidden directories like .git
        if not any(part.startswith('.') for part in os.path.join(root, f).split(os.sep)):
            tree_output.append(f"{sub_indent}{f}")

final_summary.append("\n".join(tree_output))
final_summary.append("\n\n--- FILE CONTENTS ---\n")

# Part 2: Append the content of each relevant file
for root, dirs, files in os.walk(project_root):
    # Prune ignored directories again
    dirs[:] = [d for d in dirs if d not in ignore_dirs]

    for file in sorted(files):
        file_path = os.path.join(root, file)
        file_ext = os.path.splitext(file)[1]

        if file_ext in include_extensions:
            # Make sure we are not in a hidden directory
            if not any(part.startswith('.') for part in file_path.split(os.sep)):
                final_summary.append(f"\n--- File: {file_path} ---\n")
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        final_summary.append(f.read())
                except Exception as e:
                    final_summary.append(f"Error reading file: {e}")

# Create the final output file
with open('project_summary.txt', 'w', encoding='utf-8') as f:
    f.write("".join(final_summary))

print("Successfully created 'project_summary.txt' with the project overview.")


