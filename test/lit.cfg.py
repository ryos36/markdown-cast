import lit.formats
import os

config.name = 'markdown-cast'
config.test_format = lit.formats.ShTest()
config.suffixes = ['.test']

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
config.test_exec_root = os.path.join(root, '_build', 'test-tmp')
