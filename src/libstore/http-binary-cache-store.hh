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

    HttpAuthMethod parseHttpAuthMethod(const std::string &str) {
        static const std::map<std::string, HttpAuthMethod> map = {
            {"basic", HttpAuthMethod::BASIC},
            {"digest", HttpAuthMethod::DIGEST},
            {"negotiate", HttpAuthMethod::NEGOTIATE},
            {"ntlm", HttpAuthMethod::NTLM},
            {"bearer", HttpAuthMethod::BEARER},
            {"any", HttpAuthMethod::ANY},
            {"anysafe", HttpAuthMethod::ANYSAFE}
        };
        auto it = map.find(str);
        if (it != map.end()) {
            return it->second;
        }
        return HttpAuthMethod::BASIC;
    }
/**
 * Like `PathSetting`, but the absence of a path is also allowed.
 *
 * `std::optional` is used instead of the empty string for clarity.
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

    void operator =(const HttpAuthMethod & v);
};

}