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
#include "placeholderMachOBytes.h"

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

void ModifyExecutable(NSString* executablePath, uint32_t platform) {
    struct mach_header_64* header = (struct mach_header_64*)placeholderMachOBytes;
    // Set the architecture of the placeholder Mach-O to armv7
    header->cputype = CPU_TYPE_ARM;
    header->cpusubtype = CPU_SUBTYPE_ARM_V7;
    // Set the platform of the placeholder Mach-O
    uint8_t* imageHeaderPtr = (uint8_t*)header + sizeof(struct mach_header_64);
    struct load_command *command = (struct load_command *)imageHeaderPtr;
    for(int i = 0; i < header->ncmds > 0; ++i) {
        if(command->cmd == LC_BUILD_VERSION) {
            ((struct build_version_command*)command)->platform = platform;
            break;
        }
        imageHeaderPtr += command->cmdsize;
        command = (struct load_command *)imageHeaderPtr;
    }
    // Write the placeholder Mach-O to a temporary file
    NSString* placeholderMachOPath = MakeTMPPath();
    [[NSData dataWithBytes:placeholderMachOBytes length:sizeof(placeholderMachOBytes)] writeToFile:placeholderMachOPath options:NSDataWritingAtomic error:NULL];
    // Get the placeholder Mach-O
    MachO* placeholderMachO = fat_get_single_slice(fat_init_from_path(placeholderMachOPath.UTF8String));
    // Open up the executable
    Fat* fat = fat_init_from_path((char*)executablePath.UTF8String);
    // Insert the placeholder Mach-O slice at index 0
    fat->slicesCount++;
    fat->slices = realloc(fat->slices, sizeof(MachO*) * fat->slicesCount);
    if (!fat->slices) return;
    for (int i = fat->slicesCount - 2; i >= 0; i--) {
        fat->slices[i + 1] = fat->slices[i];
    }
    fat->slices[0] = placeholderMachO;
    // Write out the modifed executable
    NSString* tmpPath = MakeTMPPath();
    exportFAT(fat, (char*)tmpPath.UTF8String);
    [[NSFileManager defaultManager] removeItemAtPath:executablePath error:NULL];
    [[NSFileManager defaultManager] moveItemAtPath:tmpPath toPath:executablePath error:NULL];
    chmod((char*)executablePath.UTF8String, S_IRWXU | S_IRWXG | S_IRWXO);
    [[NSFileManager defaultManager] removeItemAtPath:placeholderMachOPath error:NULL];
}
