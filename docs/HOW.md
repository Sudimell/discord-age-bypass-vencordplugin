# how it works

upstream had two files: one rewrote ws packets, one rewrote headers. in vencord both are patches

**1. find where user data lands**

pulled discord's js chunks, grepped `nsfwAllowed` / `nsfw_allowed` / `ageVerificationStatus`

found the `User` constructor. ready and user_update both build a `User` from raw snake_case there, map to camel, store it

**2. enum**

same chunk has the order:

`1 unverified, 2 verified teen, 3 verified adult, 4 inferred adult, 5 inferred teen, 99999 pending`

3 = confirmed adult, so 3

**3. patch the constructor**

```
match: /this\.nsfwAllowed=\i\.nsfw_allowed\?\?\i\.nsfwAllowed,this\.ageVerificationStatus=.../
replace: this.nsfwAllowed=!0,this.ageVerificationStatus=3
```

every ready and user_update now lands adult, reconnect included. no ws shadow, no pako, no zlib

**4. server side**

grep `client_build_number`, it sits in the `X-Super-Properties` builder next to `parseInt("681709")`

```
match: parseInt("\d+",10) ... client_build_number
replace: parseInt("6000",10)
```

sent inside `X-Super-Properties` with every api call, server thinks the client is old and does not gate

**5. start / stop**

`start()` sets the same fields on the live current user and fires `CURRENT_USER_UPDATE`, so the store rebuilds and ui redraws. patches only come off on restart, so `stop()` just resets a flag

**6. why both**

drop the header patch: channels open, history dies with `Messages failed to load`. drop the user patch: no gate but acc still not adult. need both

**7. test**

fresh nsfw channel, count messages before and after `fetchMessages`. unverified acc: 0 → 5..10. send via `RestAPI.post /channels/{id}/messages`: 200

**8. limits**

uk, au, br check on the server, vpn needed. stage talk breaks on accept. old build hides quests
