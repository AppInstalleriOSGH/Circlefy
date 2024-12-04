//
//  Circlefy.m
//  Circlefy
//
//  Created by Benjamin on 12/3/24.
//

#include <Foundation/Foundation.h>
#include "choma/FileStream.h"
#include "choma/CodeDirectory.h"
#include "choma/MachOLoadCommand.h"
#include "choma/Fat.h"
#include "choma/MachO.h"
#include "choma/Util.h"
#include "visionOSMachO.h"

#define ARM64_ALIGNMENT 0xE

void exportFAT(Fat* fat, char* outputPath) {
    printf("Created Fat with %u slices.\n", fat->slicesCount);
    struct fat_header fatHeader;
    fatHeader.magic = FAT_MAGIC;
    fatHeader.nfat_arch = fat->slicesCount;
    FAT_HEADER_APPLY_BYTE_ORDER(&fatHeader, HOST_TO_BIG_APPLIER);
    uint64_t alignment = pow(2, ARM64_ALIGNMENT);
    uint64_t paddingSize = alignment - sizeof(struct fat_header) - (sizeof(struct fat_arch) * fat->slicesCount);
    MemoryStream *stream = file_stream_init_from_path(outputPath, 0, FILE_STREAM_SIZE_AUTO, FILE_STREAM_FLAG_WRITABLE | FILE_STREAM_FLAG_AUTO_EXPAND);
    memory_stream_write(stream, 0, sizeof(struct fat_header), &fatHeader);
    uint64_t lastSliceEnd = alignment;
    for (int i = 0; i < fat->slicesCount; i++) {
        struct fat_arch archDescriptor;
        archDescriptor.cpusubtype = fat->slices[i]->archDescriptor.cpusubtype;
        archDescriptor.cputype = fat->slices[i]->archDescriptor.cputype;
        archDescriptor.size = fat->slices[i]->archDescriptor.size;
        archDescriptor.offset = align_to_size(lastSliceEnd, alignment);
        archDescriptor.align = ARM64_ALIGNMENT;
        FAT_ARCH_APPLY_BYTE_ORDER(&archDescriptor, HOST_TO_BIG_APPLIER);
        printf("Writing to offset 0x%lx\n", sizeof(struct fat_header) + (sizeof(struct fat_arch) * i));
        memory_stream_write(stream, sizeof(struct fat_header) + (sizeof(struct fat_arch) * i), sizeof(struct fat_arch), &archDescriptor);
        lastSliceEnd += align_to_size(memory_stream_get_size(fat->slices[i]->stream), alignment);
    }
    uint8_t *padding = malloc(paddingSize);
    memset(padding, 0, paddingSize);
    memory_stream_write(stream, sizeof(struct fat_header) + (sizeof(struct fat_arch) * fat->slicesCount), paddingSize, padding);
    free(padding);
    uint64_t offset = alignment;
    for (int i = 0; i < fat->slicesCount; i++) {
        MachO *macho = fat->slices[i];
        int size = memory_stream_get_size(macho->stream);
        void *data = malloc(size);
        memory_stream_read(macho->stream, 0, size, data);
        memory_stream_write(stream, offset, size, data);
        free(data);
        uint64_t alignedSize = i == fat->slicesCount - 1 ? size : align_to_size(size, alignment);;
        printf("Slice %d: 0x%x bytes, aligned to 0x%llx bytes.\n", i, size, alignedSize);
        padding = malloc(alignedSize - size);
        memset(padding, 0, alignedSize - size);
        memory_stream_write(stream, offset + size, alignedSize - size, padding);
        free(padding);
        offset += alignedSize;
    }
    if (fat) fat_free(fat);
    if (stream) memory_stream_free(stream);
}

NSString* MakeTMPPath(void) {
    return [[[NSFileManager defaultManager] temporaryDirectory].path stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
}

void ModifyExecutable(NSString* executablePath) {
    // Write the visionOS Mach-O to a temporary file
    NSString* visionOSMachOPath = MakeTMPPath();
    [[[NSData alloc] initWithBase64EncodedString:visionOSMachOB64 options:0] writeToFile:visionOSMachOPath options:NSDataWritingAtomic error:NULL];
    // Get the visionOS Mach-O
    MachO* visionOSMachO = fat_get_single_slice(fat_init_from_path(visionOSMachOPath.UTF8String));
    // Open up the executable
    Fat* fat = fat_init_from_path((char*)executablePath.UTF8String);
    // Insert the visionOS slice at index 0
    fat->slicesCount++;
    fat->slices = realloc(fat->slices, sizeof(MachO*) * fat->slicesCount);
    if (!fat->slices) return;
    for (int i = fat->slicesCount - 2; i >= 0; i--) {
        fat->slices[i + 1] = fat->slices[i];
    }
    fat->slices[0] = visionOSMachO;
    // Write it out
    NSString* tmpPath = MakeTMPPath();
    exportFAT(fat, (char*)tmpPath.UTF8String);
    [[NSFileManager defaultManager] removeItemAtPath:executablePath error:NULL];
    [[NSFileManager defaultManager] moveItemAtPath:tmpPath toPath:executablePath error:NULL];
    chmod((char*)executablePath.UTF8String, S_IRWXU | S_IRWXG | S_IRWXO);
    [[NSFileManager defaultManager] removeItemAtPath:visionOSMachOPath error:NULL];
}
