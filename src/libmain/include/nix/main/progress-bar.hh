#pragma once
///@file

#include "nix/util/logging.hh"

namespace nix {

/**
 * @param multiline Show every running activity on its own line below
 * the status line, rather than only the most recent one.
 */
std::unique_ptr<Logger> makeProgressBar(bool multiline = false);

} // namespace nix
