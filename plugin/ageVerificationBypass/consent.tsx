/*
 * Vencord, a Discord client mod
 * Copyright (c) 2026 Sudimell and contributors
 * SPDX-License-Identifier: MIT
 */

import { del, get, set } from "@api/DataStore";
import { Settings } from "@api/Settings";
import { Button } from "@components/Button";
import { ErrorBoundary } from "@components/index";
import { Margins } from "@components/margins";
import { Paragraph } from "@components/Paragraph";
import { RenderModalProps } from "@vencord/discord-types";
import { FluxDispatcher, Modal, openModal, RestAPI, showToast, useEffect, useState } from "@webpack/common";

const KEY = "AgeVerificationBypass_consent";
const AUTHOR_KEY = "AgeVerificationBypass_author";
const NAME = "AgeVerificationBypass";
const WAIT = 10;
const FALLBACK = ["sudo", "sudi", "spoofie"];

const rule = { borderTop: "1px solid var(--background-modifier-accent)", margin: "16px 0" };
const locked = { onCloseRequest: () => { } };

async function authorName() {
    const cached = await get(AUTHOR_KEY);
    if (cached) return cached;

    try {
        const res = await fetch("https://api.github.com/users/Sudimell");
        if (res.ok) {
            const data = await res.json();
            const name = data.name || data.login;
            if (name) {
                void set(AUTHOR_KEY, name);
                return name;
            }
        }
    } catch { }

    return FALLBACK[Math.floor(Math.random() * FALLBACK.length)];
}

function Next(props: RenderModalProps) {
    const [name, setName] = useState("friend");

    useEffect(() => { void authorName().then(setName); }, []);

    return (
        <Modal
            {...props}
            title="hey there"
            actions={[{
                text: "continue",
                variant: "primary",
                onClick() {
                    props.onClose();
                    showDisclaimer();
                }
            }]}
        >
            <div className="avb-consent">
                <Paragraph className={Margins.bottom8}>its me, <b>sudi</b>, the one who made this plugin.</Paragraph>

                <Paragraph className={Margins.bottom8}>
                    lets make some things clear. this can lead ur account to get <b>limited</b>, or even worse, <b>banned</b>.
                    honestly i cant tell much which exactly can happen, since its my first time making this type of vencord plugin.
                </Paragraph>

                <Paragraph className={Margins.bottom8}>
                    also this plugin might not work in <b>the Federative Republic of Brazil</b>,{" "}
                    <b>the United Kingdom of Great Britain and Northern Ireland</b> or <b>the Commonwealth of Australia</b>.
                    discord patched their apis for those a long time ago, use a vpn to make the plugin work there.
                </Paragraph>

                <div style={rule} />

                <Paragraph>enjoy using this plugin, <b>{name}</b>!</Paragraph>
            </div>
        </Modal>
    );
}

function Disclaimer(props: RenderModalProps) {
    const [left, setLeft] = useState(WAIT);

    useEffect(() => {
        if (left <= 0) return;
        const t = setTimeout(() => setLeft(v => v - 1), 1000);
        return () => clearTimeout(t);
    }, [left]);

    return (
        <Modal
            {...props}
            title="by using this plugin you agree that"
            actions={[
                {
                    text: "i disagree (disables extension)",
                    variant: "secondary",
                    onClick() {
                        void disable();
                        props.onClose();
                    }
                },
                {
                    text: left > 0 ? `i agree (${left})` : "i agree",
                    variant: "primary",
                    disabled: left > 0,
                    onClick() {
                        void set(KEY, true);
                        props.onClose();
                    }
                }
            ]}
        >
            <div className="avb-consent">
                <Paragraph className={Margins.bottom8}>
                    sudi did nothing bad by being russian and living in russia.
                </Paragraph>

                <Paragraph className={Margins.bottom8}>
                    <i>(sudi does not support the war between russia and ukraine, and all sudi wants is peace)</i>
                </Paragraph>

                <div style={rule} />

                <Paragraph>
                    sudi or any other person who made this bypass is not responsible for any actions that discord can do to ur
                    account by using this plugin. by pressing <b>i agree</b> ure know whatcha doin and what can happen.
                </Paragraph>
            </div>
        </Modal>
    );
}

async function disable() {
    Settings.plugins[NAME].enabled = false;

    // the patch now sees enabled = false, so pulling raw user data actually sticks
    try {
        const res = await RestAPI.get({ url: "/users/@me" });
        if (res.ok && res.body) FluxDispatcher.dispatch({ type: "CURRENT_USER_UPDATE", user: res.body });
    } catch { }

    showToast({ text: "disabled. restart discord to unload it fully" });
}

function showDisclaimer() {
    openModal(props => (
        <ErrorBoundary noop>
            <Disclaimer {...props} />
        </ErrorBoundary>
    ), locked);
}

export async function maybeShowConsent() {
    if (await get(KEY)) return;

    openModal(props => (
        <ErrorBoundary noop>
            <Next {...props} />
        </ErrorBoundary>
    ), locked);
}

export function ResetIntro() {
    return (
        <Button
            size="small"
            onClick={async () => {
                await del(KEY);
                showToast({ text: "intro reset, restart discord to see it again" });
            }}
        >
            show intro again
        </Button>
    );
}
