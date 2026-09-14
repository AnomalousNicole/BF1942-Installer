// VulkanCheck - decides whether the PC can run DXVK 2.7.1.
// Built as a 32-bit exe on purpose: BF1942 is 32-bit, so the 32-bit Vulkan loader
// (SysWOW64\vulkan-1.dll) is the one DXVK will actually use.
//
// DXVK 2.x requirements checked:
//   * a Vulkan 1.3 capable GPU driver (integrated, discrete or virtual GPU - not a CPU renderer)
//   * VK_EXT_robustness2 (or VK_KHR_robustness2)
//   * core feature robustBufferAccess
//
// Exit code 0 = DXVK supported, 1 = not supported (use dgVoodoo2), 2 = unexpected error.
// Human readable details are printed to stdout for the installer to show / log.
using System;
using System.Runtime.InteropServices;
using System.Text;

static class VulkanCheck
{
    [StructLayout(LayoutKind.Sequential)]
    struct VkInstanceCreateInfo
    {
        public int sType;
        public IntPtr pNext;
        public uint flags;
        public IntPtr pApplicationInfo;
        public uint enabledLayerCount;
        public IntPtr ppEnabledLayerNames;
        public uint enabledExtensionCount;
        public IntPtr ppEnabledExtensionNames;
    }

    const int VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO = 1;
    const int VK_SUCCESS = 0;
    const int VK_INCOMPLETE = 5;

    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkCreateInstance(ref VkInstanceCreateInfo info, IntPtr allocator, out IntPtr instance);
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkDestroyInstance(IntPtr instance, IntPtr allocator);
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkEnumeratePhysicalDevices(IntPtr instance, ref uint count, IntPtr[] devices);
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkGetPhysicalDeviceProperties(IntPtr device, byte[] properties);
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern void vkGetPhysicalDeviceFeatures(IntPtr device, byte[] features);
    [DllImport("vulkan-1.dll", CallingConvention = CallingConvention.StdCall)]
    static extern int vkEnumerateDeviceExtensionProperties(IntPtr device, IntPtr layerName, ref uint count, byte[] properties);

    static string CString(byte[] buf, int offset, int max)
    {
        int end = offset;
        while (end < offset + max && buf[end] != 0) end++;
        return Encoding.UTF8.GetString(buf, offset, end - offset);
    }

    static int Main()
    {
        try
        {
            var info = new VkInstanceCreateInfo { sType = VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO };
            IntPtr instance;
            int res = vkCreateInstance(ref info, IntPtr.Zero, out instance);
            if (res != VK_SUCCESS)
            {
                Console.WriteLine("No usable Vulkan driver (vkCreateInstance returned " + res + ").");
                return 1;
            }

            bool supported = false;
            try
            {
                uint count = 0;
                vkEnumeratePhysicalDevices(instance, ref count, null);
                if (count == 0)
                {
                    Console.WriteLine("No Vulkan GPU found.");
                    return 1;
                }
                var devices = new IntPtr[count];
                vkEnumeratePhysicalDevices(instance, ref count, devices);

                for (int i = 0; i < count; i++)
                {
                    var props = new byte[8192]; // VkPhysicalDeviceProperties is ~830 bytes; oversized on purpose
                    vkGetPhysicalDeviceProperties(devices[i], props);
                    uint api = BitConverter.ToUInt32(props, 0);
                    uint type = BitConverter.ToUInt32(props, 16);
                    string name = CString(props, 20, 256);
                    uint major = (api >> 22) & 0x7F, minor = (api >> 12) & 0x3FF;

                    uint extCount = 0;
                    vkEnumerateDeviceExtensionProperties(devices[i], IntPtr.Zero, ref extCount, null);
                    var exts = new byte[Math.Max(extCount, 1) * 260]; // VkExtensionProperties = char[256] + uint32
                    vkEnumerateDeviceExtensionProperties(devices[i], IntPtr.Zero, ref extCount, exts);
                    bool robustness2 = false;
                    for (int e = 0; e < extCount; e++)
                    {
                        string ext = CString(exts, e * 260, 256);
                        if (ext == "VK_EXT_robustness2" || ext == "VK_KHR_robustness2") robustness2 = true;
                    }

                    var features = new byte[55 * 4 + 64];
                    vkGetPhysicalDeviceFeatures(devices[i], features);
                    bool robustBufferAccess = BitConverter.ToUInt32(features, 0) != 0;

                    bool isGpu = type >= 1 && type <= 3;
                    bool ok = isGpu && (major > 1 || (major == 1 && minor >= 3)) && robustness2 && robustBufferAccess;
                    Console.WriteLine(string.Format("GPU: {0} | Vulkan {1}.{2} | robustness2: {3} | DXVK 2.7.1: {4}",
                        name, major, minor, robustness2 ? "yes" : "no", ok ? "supported" : "not supported"));
                    supported |= ok;
                }
            }
            finally
            {
                vkDestroyInstance(instance, IntPtr.Zero);
            }
            return supported ? 0 : 1;
        }
        catch (DllNotFoundException)
        {
            Console.WriteLine("Vulkan runtime (vulkan-1.dll) is not installed.");
            return 1;
        }
        catch (EntryPointNotFoundException)
        {
            Console.WriteLine("Vulkan runtime is too old.");
            return 1;
        }
        catch (Exception ex)
        {
            Console.WriteLine("Vulkan check failed: " + ex.Message);
            return 2;
        }
    }
}
