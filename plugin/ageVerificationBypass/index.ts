/*
 * Vencord, a Discord client mod
 * Copyright (c) 2026 Sudimell and contributors
 * SPDX-License-Identifier: MIT
 *
 * repo: https://github.com/sudimell/discord-age-bypass-vencordplugin
 *
 * forked from age-verification-bypass by helloyanis (mit), the extension part
 * old build trick by etsycom: spoofing an old version stops the api blocking messages
 */

import { definePluginSettings, Settings } from "@api/Settings";
import { User } from "@vencord/discord-types";
import definePlugin, { OptionType } from "@utils/types";
import { FluxDispatcher, UserStore } from "@webpack/common";

import { maybeShowConsent, ResetIntro } from "./consent";
import managedStyle from "./consent.css?managed";

const NAME = "AgeVerificationBypass";

/** adult */
const ADULT = 3;

const settings = definePluginSettings({
    spoofClientBuild: {
        type: OptionType.BOOLEAN,
        description: "bypass part 1: old client build. turning it off breaks history and sending in nsfw channels",
        default: true,
        restartNeeded: true
    },
    spoofAgeStatus: {
        type: OptionType.BOOLEAN,
        description: "bypass part 2: adult status. turning it off brings the age wall back",
        default: true,
        restartNeeded: true
    },
    resetIntro: {
        type: OptionType.COMPONENT,
        description: "bring the first launch window back",
        component: ResetIntro
    }
});

let spoofed = false;

function applySpoof(user: User) {
    user.nsfwAllowed = true;
    user.ageVerificationStatus = ADULT;

    // store rebuild so ui redraws
    FluxDispatcher.dispatch({ type: "CURRENT_USER_UPDATE", user: { ...user } });
}

export default definePlugin({
    name: "AgeVerificationBypass",
    description: "hides the age wall in discord. spoofs you as adult and sends an old client build so messages load and send",
    authors: [
        { name: "helloyanis", id: 336458121180610560n },
        { name: "Sudimell", id: 601447059115081759n }
    ],
    settings,
    managedStyle,

    patches: [
        {
            // client spoof. no it = no messages
            find: "native_build_number",
            predicate: () => settings.store.spoofClientBuild,
            replacement: {
                match: /isNaN\((\i)=parseInt\("\d+",10\)\)\|\|\((\i)\.client_build_number=\1\)/,
                replace: "isNaN($1=parseInt(\"6000\",10))||($2.client_build_number=$1)"
            }
        },
        {
            // user spoof. ready + user_update go thru here
            find: "this.nsfwAllowed=",
            predicate: () => settings.store.spoofAgeStatus,
            replacement: {
                match: /this\.nsfwAllowed=(\i)\.nsfw_allowed\?\?\1\.nsfwAllowed,this\.ageVerificationStatus=\1\.age_verification_status\?\?\1\.ageVerificationStatus,/,
                replace: "this.nsfwAllowed=$self.spoofing()?!0:($1.nsfw_allowed??$1.nsfwAllowed),this.ageVerificationStatus=$self.spoofing()?3:($1.age_verification_status??$1.ageVerificationStatus),"
            }
        }
    ],

    start() {
        void maybeShowConsent();

        if (!settings.store.spoofAgeStatus || spoofed) return;

        const user = UserStore.getCurrentUser();
        if (!user) return;

        spoofed = true;
        applySpoof(user);
    },

    // checked from inside the patched constructor, so disagree can turn it off live
    spoofing() {
        return Settings.plugins[NAME]?.enabled !== false;
    },

    stop() {
        // patches off on restart only, flag lets start rerun
        spoofed = false;
    }
});
