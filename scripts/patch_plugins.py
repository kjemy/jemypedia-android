import os
import re

def main():
    pub_cache = os.environ.get('PUB_CACHE')
    if not pub_cache:
        pub_cache = os.path.expanduser('~/.pub-cache')

    print(f"Using pub_cache path: {pub_cache}")

    for root, dirs, files in os.walk(pub_cache):
        for file in files:
            if file == 'build.gradle':
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                        content = f.read()
                    
                    if 'android {' in content:
                        modified = False
                        
                        # 1. Check and inject namespace
                        if 'namespace' not in content:
                            # Try to find AndroidManifest.xml package name
                            manifest_path = os.path.join(os.path.dirname(filepath), 'src', 'main', 'AndroidManifest.xml')
                            pkg = None
                            if os.path.exists(manifest_path):
                                with open(manifest_path, 'r', encoding='utf-8', errors='ignore') as mf:
                                    manifest_content = mf.read()
                                m = re.search(r'package=["\']([^"\']+)["\']', manifest_content)
                                if m:
                                    pkg = m.group(1)
                            
                            if not pkg:
                                # Fallback: look for group in build.gradle
                                m = re.search(r'group\s*=?\s*["\']([^"\']+)["\']', content)
                                if m:
                                    pkg = m.group(1)
                                    
                            if pkg:
                                print(f"Patching namespace '{pkg}' into {filepath}")
                                # Inject namespace 'pkg' inside android {
                                content = content.replace('android {', f"android {{\n    namespace '{pkg}'")
                                modified = True
                        
                        # 2. Check and upgrade compileSdkVersion / compileSdk to 34
                        # We replace both compileSdkVersion and compileSdk declarations with compileSdk 34
                        new_content = content
                        
                        # Find compileSdkVersion and replace
                        if 'compileSdkVersion' in new_content:
                            new_content = re.sub(r'compileSdkVersion\s*=?\s*.*', 'compileSdk 34', new_content)
                            
                        # Find compileSdk (if not 34) and replace
                        if 'compileSdk' in new_content:
                            new_content = re.sub(r'compileSdk\s*=?\s*(?!34\b)\d+', 'compileSdk 34', new_content)
                            # Handle case where compileSdk is set to a variable/property
                            new_content = re.sub(r'compileSdk\s*=?\s*(?!34\b)[a-zA-Z._]+', 'compileSdk 34', new_content)

                        if new_content != content:
                            content = new_content
                            modified = True
                            print(f"Patching compileSdk to 34 in {filepath}")
                            
                        if modified:
                            with open(filepath, 'w', encoding='utf-8') as f:
                                f.write(content)
                                
                except Exception as e:
                    print(f"Error patching {filepath}: {e}")

if __name__ == '__main__':
    main()
