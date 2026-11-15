#include <IOKit/IOService.h>
#include <IOKit/IOLib.h>
#include <IOKit/acpi/IOACPIPlatformDevice.h>
#include <libkern/c++/OSData.h>
#include <libkern/c++/OSNumber.h>
#include <mach/kmod.h>

extern "C" kern_return_t _start(kmod_info_t *, void *);
extern "C" kern_return_t _stop(kmod_info_t *, void *);
extern "C" {
KMOD_EXPLICIT_DECL(local.delllink.TahoeBacklightProbe, "1.0.0", _start, _stop)
__private_extern__ kmod_start_func_t *_realmain = nullptr;
__private_extern__ kmod_stop_func_t *_antimain = nullptr;
__private_extern__ int _kext_apple_cc = 1;
}

class DellBacklightProbe : public IOService {
    OSDeclareDefaultStructors(DellBacklightProbe)

    static IOReturn read(IOACPIPlatformDevice *acpi, UInt32 method, UInt32 mode, UInt32 &value) {
        UInt32 buffer[6] = {mode, 0, 0, 0, 0, 0};
        OSObject *args[3] = {OSNumber::withNumber(0ULL, 32), OSNumber::withNumber(method, 32),
                             OSData::withBytes(buffer, sizeof(buffer))};
        OSObject *out = nullptr;
        IOReturn status = kIOReturnNoMemory;
        if (args[0] && args[1] && args[2]) {
            status = acpi->evaluateObject("WMAA", &out, args, 3);
            const auto result = OSDynamicCast(OSNumber, out);
            if (status == kIOReturnSuccess && result) value = result->unsigned32BitValue();
            else if (status == kIOReturnSuccess) status = kIOReturnBadArgument;
        }
        for (auto arg : args) if (arg) arg->release();
        if (out) out->release();
        return status;
    }

public:
    bool start(IOService *provider) override {
        if (!IOService::start(provider)) return false;
        auto acpi = OSDynamicCast(IOACPIPlatformDevice, provider);
        if (!acpi) return false;

        OSObject *out = nullptr;
        const IOReturn status = acpi->evaluateObject("_WDG", &out);
        const auto ids = OSDynamicCast(OSData, out);
        static const UInt8 guid[20] = {0x13, 0x96, 0x3e, 0x60, 0x25, 0xef, 0x38, 0x43,
                                       0xa3, 0xd0, 0xc4, 0x61, 0x77, 0x51, 0x6d, 0xb7,
                                       0x41, 0x41, 1, 2};
        bool found = false;
        if (status == kIOReturnSuccess && ids) {
            for (unsigned off = 0; off + sizeof(guid) <= ids->getLength(); off += sizeof(guid)) {
                const auto entry = ids->getBytesNoCopy(off, sizeof(guid));
                if (entry && !memcmp(entry, guid, sizeof(guid))) { found = true; break; }
            }
        }
        if (out) out->release();
        IOLog("DellBacklightProbe: %s WDG=0x%x match=%u\n", provider->getName(), status, found);
        if (!found) return false;

        UInt32 source = 0, maximum = 0, current = 0;
        const auto sourceStatus = read(acpi, 2, 0, source);
        const auto maxStatus = read(acpi, 1, 2, maximum);
        const auto currentStatus = read(acpi, 1, 0, current);
        setProperty("SourceStatus", static_cast<UInt32>(sourceStatus), 32);
        setProperty("MaximumStatus", static_cast<UInt32>(maxStatus), 32);
        setProperty("CurrentStatus", static_cast<UInt32>(currentStatus), 32);
        setProperty("BrightnessSource", source, 32);
        setProperty("BrightnessMaximum", maximum, 32);
        setProperty("BrightnessCurrent", current, 32);
        IOLog("DellBacklightProbe: %s source=%u(0x%x) maximum=%u(0x%x) current=%u(0x%x)\n",
              provider->getName(), source, sourceStatus, maximum, maxStatus, current, currentStatus);
        registerService();
        return true;
    }
};

OSDefineMetaClassAndStructors(DellBacklightProbe, IOService)
