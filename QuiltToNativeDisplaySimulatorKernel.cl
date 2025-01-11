// the resolution of the result must be horizontally multiple of rows*cols
__kernel void kernelMain(__read_only image2d_t inputImage, __write_only image2d_t outputImage, int rows, int cols, float tilt, float pitch, float center, float viewPortionElement, float subp, float focus) 
{
    const sampler_t imageSampler = CLK_NORMALIZED_COORDS_TRUE | CLK_ADDRESS_CLAMP_TO_EDGE | CLK_FILTER_LINEAR;
    int2 coords = (int2)(get_global_id(0), get_global_id(1)); 
    float2 coordsNormalized = (float2)((float)get_global_id(0)/(get_image_width(outputImage)-1), (float)get_global_id(1)/(get_image_height(outputImage)-1));

    if (coordsNormalized[0] > 1.0f || coordsNormalized[1] > 1.0f)
        return;

    int views = cols*rows;
    float viewInternalCoordsX = (coords[0] / views) / (float)((get_image_width(outputImage) / views)); 
    int currentPixelView = coords[0] % views;
    currentPixelView = (float)(((int)currentPixelView%cols)+(rows-1-(int)currentPixelView/cols)*cols);
    int2 viewCoords = (int2)(currentPixelView % cols, currentPixelView / cols);
    float2 viewRange = (float2)(1.0f/cols, 1.0f/rows);
    float2 sampleCoords = (float2)(viewRange[0]*viewCoords[0] + viewInternalCoordsX/cols, viewRange[1]*viewCoords[1] + coordsNormalized[1]/rows);
    uint4 pixel = read_imageui(inputImage, imageSampler, sampleCoords);
	write_imageui(outputImage, coords, pixel);
}
