#pragma once
///@file

#include "binary-cache-store.hh"
#include "types.hh"
#include <curl/curl.h>

namespace nix {
    enum struct HttpAuthMethod : unsigned long {
        BASIC = CURLAUTH_BASIC,
        DIGEST = CURLAUTH_DIGEST,
        NEGOTIATE = CURLAUTH_NEGOTIATE,
        NTLM = CURLAUTH_NTLM,
        BEARER = CURLAUTH_BEARER,
        ANY = CURLAUTH_ANY,
        ANYSAFE = CURLAUTH_ANYSAFE
    };

/**
 * A setting for curl's HTTP authentication methods
 *
 * Unknown values default to BASIC, which is the also the default in curl.
 */
class HttpAuthMethodSetting : public BaseSetting<HttpAuthMethod>
{
public:

    HttpAuthMethodSetting(Config * options,
        const HttpAuthMethod & def,
        const std::string & name,
        const std::string & description,
        const std::set<std::string> & aliases = {});

    HttpAuthMethod parse(const std::string & str) const override;

    void operator =(const HttpAuthMethod & v) { this->assign(v); }
};

}