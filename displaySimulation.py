import bpy
import sys

argv = sys.argv
argv = argv[argv.index("--") + 1:]
file = str(argv[0])
output = str(argv[1])
image = bpy.data.images.load(file, check_existing=False)
bpy.data.materials["Material.003"].node_tree.nodes["Image Texture"].image = image
bpy.data.scenes["Scene"].render.filepath = output
bpy.ops.render.render(animation=True, write_still=True)
