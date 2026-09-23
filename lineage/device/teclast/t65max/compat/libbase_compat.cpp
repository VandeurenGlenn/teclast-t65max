/*
 * SPDX-License-Identifier: Apache-2.0
 *
 * Compatibility entry points removed from newer libbase revisions but still
 * imported by the verified A8D4 vendor binaries.
 */

#include <android-base/file.h>
#include <android-base/strings.h>

#include <string>
#include <string_view>

namespace android::base {

std::string Trim(const std::string& input) {
    return Trim(std::string_view(input));
}

std::string Basename(const std::string& path) {
    return Basename(std::string_view(path));
}

bool WriteStringToFd(const std::string& content, borrowed_fd fd) {
    return WriteStringToFd(std::string_view(content), fd);
}

}  // namespace android::base
