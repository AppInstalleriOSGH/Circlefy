# Circlefy  

**Circlefy** is an iOS app designed to modify `.ipa` files to give their app icons a circular appearance or no mask at all, which allows transparent icons of any shape. It achieves this through a unique technique involving platform detection behavior in Mach-O binaries.

## How Does It Work?  

1. **Platform Detection**:  
   iOS detects the platform of the app's executable from the Mach-O file. Depending on the platform identifier, the system alters the app icon's appearance.  
   - **visionOS (Platform 11)**: Icons appear circular.  
   - **macOS (Platform 1)**: Icons bypass iOS's icon masking entirely, enabling custom shapes without any restrictions, similar to macOS behavior. 

2. **The Fix**:  
   Circlefy modifies the **executable file** of the `.ipa` to include two FAT slices:  
   - The **first slice** is a placeholder binary for either the visionOS or macOS platform, depending on the desired icon effect.  
   - The **second slice** is the original app binary.  

3. **iOS Kernel Behavior**:  
   The iOS kernel evaluates the FAT slices in the binary and selects the most compatible executable for the device. This ensures the app functions correctly while retaining the modified icon behavior.  

## Notes  

- Circlefy is compatible only with **iOS 17 and 18** running on **arm64e devices** (A12 and newer).
- Applications modified by Circlefy will **not work** when installed with **TrollStore** because **TrollStore** extracts only the best slice from the FAT binary. This removes the necessary placeholder slice required for the modified icon behavior, rendering the modification ineffective.

## Credits  

[@opa334](https://github.com/opa334) for [ChOma](https://github.com/opa334/ChOma) used for FAT manipulating.  
[ZIPFoundation](https://github.com/weichsel/ZIPFoundation) used for repackaging the ipa.
