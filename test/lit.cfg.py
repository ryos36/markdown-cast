import lit.formats
import os
import subprocess

config.name = 'markdown-cast'
config.test_format = lit.formats.ShTest()
config.suffixes = ['.test']

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
config.test_exec_root = os.path.join(root, '_build', 'test-tmp')

def has_tool(name):
    try:
        subprocess.run(['which', name], capture_output=True, check=True)
        return True
    except subprocess.CalledProcessError:
        return False

for tool in ['npx', 'gst-launch-1.0', 'ffprobe', 'sox', 'ffmpeg', 'ninja', 'podman']:
    if has_tool(tool):
        config.available_features.add(tool)
