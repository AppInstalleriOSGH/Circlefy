# Circlefy  

**Circlefy** is an iOS app designed to modify `.ipa` files to give their app icons a circular appearance. It achieves this through a unique technique involving visionOS platform detection behavior.  

## How Does It Work?  

1. **visionOS Detection**:  
   iOS detects the platform of the app's executable from the Mach-O file. When a visionOS platform (platform 11) is detected, the system applies a circular icon to the app. However, apps designed for visionOS would typically crash on iOS devices due to incompatibility.  

2. **The Fix**:  
   Circlefy modifies the **executable file** of the `.ipa` to include two FAT slices:  
   - The **first slice** is an x86 visionOS binary, acting as a placeholder to trigger the circular icon behavior.  
   - The **second slice** is the original app binary.  

3. **iOS Kernel Behavior**:  
   The iOS kernel evaluates the FAT slices in the binary and selects the most compatible executable for the device. This ensures the app functions correctly while retaining the circular icon effect.  

## Notes  

- Circlefy is compatible only with **iOS 17 and 18** running on **arm64e devices** (A12 and newer).  
