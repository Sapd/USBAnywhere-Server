# Native macOS implementation and support: Denis Arnst (Sapd) — https://github.com/Sapd
# USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
# Licensed under GPL-3.0; see the repository LICENSE.
if (-not ('VKBNative' -as [type])) { Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class VKBNative {
    [StructLayout(LayoutKind.Sequential)] public struct State {
        public uint size,flags,x,y,z,r,u,v,buttons,buttonNumber,pov,reserved1,reserved2;
    }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] public struct Caps {
        public ushort vendor,product;
        [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string name;
        public uint xmin,xmax,ymin,ymax,zmin,zmax,buttons,periodmin,periodmax;
        public uint rmin,rmax,umin,umax,vmin,vmax,capabilities,maxAxes,axes,maxButtons;
        [MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)] public string registryKey;
        [MarshalAs(UnmanagedType.ByValTStr,SizeConst=260)] public string oem;
    }
    [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] public struct DeviceInstance {
        public uint size; public Guid instance,product; public uint type;
        [MarshalAs(UnmanagedType.ByValTStr,SizeConst=260)] public string instanceName;
        [MarshalAs(UnmanagedType.ByValTStr,SizeConst=260)] public string productName;
        public Guid forceFeedback; public ushort usagePage,usage;
    }
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] public delegate int EnumDevice(IntPtr device,IntPtr context);
    [UnmanagedFunctionPointer(CallingConvention.StdCall)] delegate int EnumMethod(IntPtr self,uint type,EnumDevice callback,IntPtr context,uint flags);
    [DllImport("dinput8.dll")] static extern int DirectInput8Create(IntPtr module,uint version,ref Guid iid,out IntPtr input,IntPtr outer);
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode)] static extern IntPtr GetModuleHandle(string name);
    [DllImport("winmm.dll")] public static extern uint joyGetPosEx(uint id,ref State state);
    [DllImport("winmm.dll",EntryPoint="joyGetDevCapsW")] public static extern uint joyGetDevCaps(uint id,out Caps caps,uint size);
    public static DeviceInstance[] DirectInputDevices() {
        Guid iid=new Guid("BF798031-483A-4DA2-AA99-5D64ED369700"); IntPtr input;
        int result=DirectInput8Create(GetModuleHandle(null),0x0800,ref iid,out input,IntPtr.Zero);
        if(result<0) Marshal.ThrowExceptionForHR(result);
        try {
            var devices=new List<DeviceInstance>();
            EnumDevice callback=delegate(IntPtr pointer,IntPtr ignored) { devices.Add((DeviceInstance)Marshal.PtrToStructure(pointer,typeof(DeviceInstance))); return 1; };
            IntPtr vtable=Marshal.ReadIntPtr(input);
            EnumMethod enumerate=(EnumMethod)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(vtable,4*IntPtr.Size),typeof(EnumMethod));
            result=enumerate(input,4,callback,IntPtr.Zero,1);
            GC.KeepAlive(callback); if(result<0) Marshal.ThrowExceptionForHR(result);
            return devices.ToArray();
        } finally { Marshal.Release(input); }
    }
}
'@ }
