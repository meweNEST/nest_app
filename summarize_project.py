#!/usr/bin/env python3
"""
Project Summarizer for LLM Understanding
Analyzes a codebase and creates a concise summary optimized for LLM consumption.
"""

import os
import json
from pathlib import Path
from collections import defaultdict
import re

class ProjectSummarizer:
    def __init__(self, repo_path='.', include_code=True, max_file_size=50000):
        self.repo_path = Path(repo_path)
        self.summary = []
        self.file_stats = defaultdict(int)
        self.important_files = []
        self.include_code = include_code
        self.max_file_size = max_file_size  # Max chars per file to include
        
        # Ignore patterns
        self.ignore_patterns = {
            '.git', 'node_modules', '.dart_tool', 'build', '.idea',
            '__pycache__', 'venv', '.env', 'dist', 'coverage',
            '.gradle', '.vscode', 'ios/Pods', 'android/build',
            'generated', '.metadata', '.flutter-plugins'
        }
        
        # File extensions to analyze
        self.code_extensions = {
            '.dart', '.py', '.js', '.ts', '.java', '.kt', '.swift',
            '.yaml', '.yml', '.json', '.md', '.xml', '.gradle'
        }
        
        # Priority extensions (always include full content)
        self.priority_extensions = {
            '.dart', '.yaml', '.yml', '.md', '.json'
        }
        
        # Important file names
        self.important_names = {
            'readme.md', 'pubspec.yaml', 'package.json', 'main.dart',
            'config.yaml', 'app.dart', 'routes.dart', 'model', 'models'
        }

    def should_ignore(self, path):
        """Check if path should be ignored"""
        parts = path.parts
        for pattern in self.ignore_patterns:
            if pattern in parts:
                return True
        return False

    def get_file_purpose(self, filepath):
        """Infer the purpose of a file from its path and name"""
        name = filepath.name.lower()
        path_str = str(filepath).lower()
        
        if 'test' in path_str:
            return 'test'
        elif 'model' in path_str:
            return 'model'
        elif 'view' in path_str or 'screen' in path_str or 'page' in path_str:
            return 'ui'
        elif 'controller' in path_str or 'bloc' in path_str or 'provider' in path_str:
            return 'logic'
        elif 'service' in path_str or 'api' in path_str:
            return 'service'
        elif 'route' in path_str or 'navigation' in path_str:
            return 'routing'
        elif 'util' in path_str or 'helper' in path_str:
            return 'utility'
        elif 'widget' in path_str or 'component' in path_str:
            return 'component'
        elif 'config' in name or name.startswith('.'):
            return 'config'
        return 'other'

    def extract_dart_info(self, content, filepath):
        """Extract key information from Dart files"""
        info = {
            'classes': [],
            'functions': [],
            'imports': [],
            'widgets': []
        }
        
        # Extract imports
        imports = re.findall(r"import\s+['\"]([^'\"]+)['\"];?", content)
        info['imports'] = imports[:5]  # Limit to first 5
        
        # Extract classes
        class_matches = re.findall(r'class\s+(\w+)(?:\s+extends\s+(\w+))?', content)
        info['classes'] = [f"{cls[0]}" + (f" extends {cls[1]}" if cls[1] else "") 
                          for cls in class_matches[:3]]
        
        # Extract widgets (StatelessWidget, StatefulWidget)
        widget_matches = re.findall(r'class\s+(\w+)\s+extends\s+(StatelessWidget|StatefulWidget)', content)
        info['widgets'] = [w[0] for w in widget_matches]
        
        # Extract top-level functions
        func_matches = re.findall(r'^(?:Future<\w+>|void|[\w<>]+)\s+(\w+)\s*\(', content, re.MULTILINE)
        info['functions'] = func_matches[:5]
        
        return info

    def extract_yaml_info(self, content, filepath):
        """Extract key information from YAML files"""
        info = {}
        
        if 'pubspec' in filepath.name.lower():
            # Extract app name
            name_match = re.search(r'^name:\s*(.+)$', content, re.MULTILINE)
            if name_match:
                info['app_name'] = name_match.group(1).strip()
            
            # Extract dependencies
            deps_section = re.search(r'dependencies:(.*?)(?=\n\w+:|$)', content, re.DOTALL)
            if deps_section:
                deps = re.findall(r'^\s+(\w+):', deps_section.group(1), re.MULTILINE)
                info['dependencies'] = deps[:10]
        
        return info

    def read_file_safely(self, filepath):
        """Read file with multiple encoding attempts"""
        encodings = ['utf-8', 'latin-1', 'cp1252']
        for encoding in encodings:
            try:
                with open(filepath, 'r', encoding=encoding) as f:
                    return f.read()
            except (UnicodeDecodeError, Exception):
                continue
        return None

    def analyze_file(self, filepath):
        """Analyze a single file and extract relevant info"""
        content = self.read_file_safely(filepath)
        if not content:
            return None
        
        relative_path = filepath.relative_to(self.repo_path)
        ext = filepath.suffix.lower()
        
        file_info = {
            'path': str(relative_path),
            'purpose': self.get_file_purpose(filepath),
            'size': len(content),
            'lines': content.count('\n'),
            'content': None  # Will store full content if needed
        }
        
        # Store full content for priority files
        if self.include_code and ext in self.priority_extensions and len(content) < self.max_file_size:
            file_info['content'] = content
        
        # Extract specific info based on file type
        if ext == '.dart':
            file_info['details'] = self.extract_dart_info(content, filepath)
        elif ext in ['.yaml', '.yml']:
            file_info['details'] = self.extract_yaml_info(content, filepath)
        elif ext == '.md':
            # Extract first few lines of README
            lines = content.split('\n')[:10]
            file_info['preview'] = '\n'.join(lines)
        
        return file_info

    def scan_directory(self):
        """Scan the repository and collect file information"""
        for filepath in self.repo_path.rglob('*'):
            if filepath.is_file():
                if self.should_ignore(filepath):
                    continue
                
                ext = filepath.suffix.lower()
                if ext in self.code_extensions or filepath.name.lower() in self.important_names:
                    self.file_stats[ext] += 1
                    
                    file_info = self.analyze_file(filepath)
                    if file_info:
                        self.important_files.append(file_info)

    def generate_summary(self):
        """Generate a comprehensive summary of the project"""
        self.summary.append("=" * 80)
        self.summary.append("PROJECT SUMMARY FOR LLM UNDERSTANDING")
        self.summary.append("=" * 80)
        self.summary.append("")
        
        # Project overview
        self.summary.append("## PROJECT OVERVIEW")
        self.summary.append("")
        
        # Find and display README
        readme_info = next((f for f in self.important_files if 'readme' in f['path'].lower()), None)
        if readme_info and 'preview' in readme_info:
            self.summary.append("README Preview:")
            self.summary.append(readme_info['preview'])
            self.summary.append("")
        
        # Find and display project config (pubspec.yaml)
        pubspec = next((f for f in self.important_files if 'pubspec.yaml' in f['path'].lower()), None)
        if pubspec and 'details' in pubspec:
            details = pubspec['details']
            if 'app_name' in details:
                self.summary.append(f"App Name: {details['app_name']}")
            if 'dependencies' in details:
                self.summary.append(f"Key Dependencies: {', '.join(details['dependencies'])}")
            self.summary.append("")
        
        # File statistics
        self.summary.append("## FILE STATISTICS")
        self.summary.append("")
        for ext, count in sorted(self.file_stats.items(), key=lambda x: x[1], reverse=True):
            self.summary.append(f"  {ext}: {count} files")
        self.summary.append("")
        
        # Group files by purpose
        files_by_purpose = defaultdict(list)
        for file_info in self.important_files:
            files_by_purpose[file_info['purpose']].append(file_info)
        
        # Display structure by purpose
        self.summary.append("## PROJECT STRUCTURE BY PURPOSE")
        self.summary.append("")
        
        purpose_order = ['config', 'model', 'ui', 'logic', 'service', 'routing', 
                        'component', 'utility', 'test', 'other']
        
        for purpose in purpose_order:
            if purpose in files_by_purpose:
                files = files_by_purpose[purpose]
                self.summary.append(f"### {purpose.upper()} ({len(files)} files)")
                self.summary.append("")
                
                for file_info in sorted(files, key=lambda x: x['path'])[:15]:  # Limit per category
                    self.summary.append(f"  📄 {file_info['path']}")
                    
                    if 'details' in file_info:
                        details = file_info['details']
                        
                        # For Dart files
                        if 'widgets' in details and details['widgets']:
                            self.summary.append(f"     Widgets: {', '.join(details['widgets'])}")
                        if 'classes' in details and details['classes']:
                            self.summary.append(f"     Classes: {', '.join(details['classes'][:3])}")
                        if 'imports' in details and details['imports'] and purpose != 'config':
                            key_imports = [imp for imp in details['imports'] if not imp.startswith('dart:')]
                            if key_imports:
                                self.summary.append(f"     Key imports: {', '.join(key_imports[:3])}")
                    
                    self.summary.append("")
                
                if len(files) > 15:
                    self.summary.append(f"  ... and {len(files) - 15} more files")
                    self.summary.append("")
        
        # Key entry points
        self.summary.append("## KEY ENTRY POINTS")
        self.summary.append("")
        main_files = [f for f in self.important_files if 'main' in f['path'].lower()]
        for file_info in main_files:
            self.summary.append(f"  🎯 {file_info['path']}")
        self.summary.append("")
        
        # Architecture insights
        self.summary.append("## ARCHITECTURE INSIGHTS")
        self.summary.append("")
        
        has_bloc = any('bloc' in f['path'].lower() for f in self.important_files)
        has_provider = any('provider' in f['path'].lower() for f in self.important_files)
        has_getx = any('getx' in f['path'].lower() for f in self.important_files)
        
        if has_bloc:
            self.summary.append("  • Uses BLoC pattern for state management")
        if has_provider:
            self.summary.append("  • Uses Provider for state management")
        if has_getx:
            self.summary.append("  • Uses GetX for state management")
        
        self.summary.append("")
        
        # Task-specific guidance
        self.summary.append("## GUIDANCE FOR NEW DEVELOPERS")
        self.summary.append("")
        self.summary.append("1. Start by reading the main entry point (usually lib/main.dart)")
        self.summary.append("2. Review models to understand data structures")
        self.summary.append("3. Check routing/navigation to understand app flow")
        self.summary.append("4. Look at services to understand external integrations")
        self.summary.append("5. Examine UI files to see how screens are built")
        self.summary.append("")
        self.summary.append("=" * 80)
        self.summary.append("")
        
        # Add full code content section if enabled
        if self.include_code:
            self.summary.append("")
            self.summary.append("=" * 80)
            self.summary.append("COMPLETE CODE CONTENT")
            self.summary.append("=" * 80)
            self.summary.append("")
            self.summary.append("Below is the complete content of all important files.")
            self.summary.append("This allows LLMs to understand the exact implementation.")
            self.summary.append("")
            
            # Sort files: config first, then by purpose
            files_with_content = [f for f in self.important_files if f.get('content')]
            
            purpose_priority = {
                'config': 0, 'model': 1, 'routing': 2, 'service': 3,
                'logic': 4, 'ui': 5, 'component': 6, 'utility': 7,
                'test': 8, 'other': 9
            }
            
            sorted_files = sorted(files_with_content, 
                                key=lambda x: (purpose_priority.get(x['purpose'], 99), x['path']))
            
            for file_info in sorted_files:
                self.summary.append("-" * 80)
                self.summary.append(f"FILE: {file_info['path']}")
                self.summary.append(f"PURPOSE: {file_info['purpose']}")
                self.summary.append(f"LINES: {file_info['lines']}")
                self.summary.append("-" * 80)
                self.summary.append("")
                self.summary.append(file_info['content'])
                self.summary.append("")
                self.summary.append("")
            
            self.summary.append("=" * 80)
            self.summary.append("END OF CODE CONTENT")
            self.summary.append("=" * 80)
        
    def save_summary(self, output_file='PROJECT_SUMMARY.txt'):
        """Save the summary to a file"""
        output_path = self.repo_path / output_file
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write('\n'.join(self.summary))
        return output_path

    def run(self, output_file='PROJECT_SUMMARY.txt'):
        """Run the complete summarization process"""
        print("🔍 Scanning repository...")
        self.scan_directory()
        
        print(f"📊 Found {len(self.important_files)} relevant files")
        
        if self.include_code:
            files_with_code = sum(1 for f in self.important_files if f.get('content'))
            print(f"📝 Including full content for {files_with_code} files")
        
        print("📝 Generating summary...")
        self.generate_summary()
        
        output_path = self.save_summary(output_file)
        total_chars = len(''.join(self.summary))
        print(f"✅ Summary saved to: {output_path}")
        print(f"📄 Summary is {total_chars:,} characters (~{total_chars // 4} tokens)")
        
        if total_chars > 500000:
            print("⚠️  Warning: Summary is quite large. Consider using --no-code flag.")
        
        return output_path


if __name__ == '__main__':
    import sys
    
    # Parse arguments
    repo_path = '.'
    output_file = 'PROJECT_SUMMARY.txt'
    include_code = True
    max_file_size = 50000
    
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        arg = args[i]
        if arg in ['--no-code', '-nc']:
            include_code = False
        elif arg in ['--max-size', '-m']:
            i += 1
            max_file_size = int(args[i])
        elif arg in ['--output', '-o']:
            i += 1
            output_file = args[i]
        elif arg in ['--help', '-h']:
            print("""
Usage: python summarize_project.py [OPTIONS] [REPO_PATH]

Options:
  --no-code, -nc          Don't include full file contents (structure only)
  --max-size, -m SIZE     Max file size to include (default: 50000 chars)
  --output, -o FILE       Output filename (default: PROJECT_SUMMARY.txt)
  --help, -h              Show this help message

Examples:
  python summarize_project.py                    # Full summary with code
  python summarize_project.py --no-code          # Structure only
  python summarize_project.py /path/to/repo      # Different repo
  python summarize_project.py -o SUMMARY.txt     # Custom output name
            """)
            sys.exit(0)
        else:
            repo_path = arg
        i += 1
    
    print(f"🚀 Project Summarizer")
    print(f"   Repo: {repo_path}")
    print(f"   Include code: {include_code}")
    print(f"   Max file size: {max_file_size:,} chars")
    print()
    
    summarizer = ProjectSummarizer(repo_path, include_code, max_file_size)
    summarizer.run(output_file)
