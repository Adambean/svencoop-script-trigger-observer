/**
 * General purpose "trigger_observer" entity.
 * By Adam "Adambean" Reece
 *
 * This can either be a brush or point entity in game.
 * When used it accepts use types on/off to force start/stop observing, or toggle to swap.
 *
 * Shamelessly stolen and improved from BM:STS but don't tell Templer what I've done.
 */

/**
 * Map initialisation handler.
 * @return void
 */
void MapInit()
{
    g_Module.ScriptInfo.SetAuthor("Adam \"Adambean\" Reece");
    g_Module.ScriptInfo.SetContactInfo("www.svencoop.com");

    TriggerObserver::Init();
}

namespace TriggerObserver
{
    /** @const float Entity loop interval. */
    const float ENT_LOOP_INTERVAL = 0.1f;

    /** @const int Do not save position when starting to observe. (Only applies to "use" input.) */
    const int FLAG_NO_SAVE_POSITION = 1<<0;

    /** @enum string Observer states */
    enum eObserverState
    {
        off                     = 0,
        onThenRespawn           = 1,
        onThenResumeOrigin      = 2,
        leavingToResumeOrigin   = 3,
    };

    /**
     * Initialise.
     * @return void
     */
    void Init()
    {
        g_CustomEntityFuncs.RegisterCustomEntity("TriggerObserver::CTriggerObserver", "trigger_observer");
        g_Scheduler.SetInterval("ObserverThink", ENT_LOOP_INTERVAL, g_Scheduler.REPEAT_INFINITE_TIMES);
    }

    /**
     * Entity: trigger_observer
     */
    final class CTriggerObserver : ScriptBaseEntity
    {
        /**
         * Key value data handler.
         * @param  string szKey   Key
         * @param  string szValue Value
         * @return bool
         */
        bool KeyValue(const string& in szKey, const string& in szValue)
        {
            return BaseClass.KeyValue(szKey, szValue);
        }

        /**
         * Spawn.
         * @return void
         */
        void Spawn()
        {
            if (self.IsBSPModel()) {
                self.pev.solid      = SOLID_TRIGGER;
                self.pev.movetype   = MOVETYPE_NONE;
                self.pev.effects    = EF_NODRAW;

                g_EntityFuncs.SetOrigin(self, self.pev.origin);
                g_EntityFuncs.SetSize(self.pev, self.pev.mins, self.pev.maxs);
                g_EntityFuncs.SetModel(self, self.pev.model);
            }
        }

        /**
         * Touch handler.
         * @param  CBaseEntity@ pOther Toucher entity
         * @return void
         */
        void Touch(CBaseEntity@ pOther)
        {
            if (!self.IsBSPModel()) {
                return;
            }

            if (pOther is null or !pOther.IsPlayer()) {
                return;
            }

            CBasePlayer@ pPlayer = cast<CBasePlayer@>(pOther);
            if (!pPlayer.IsConnected() or !pPlayer.IsAlive()) {
                return;
            }

            g_Game.AlertMessage(at_aiconsole, "CTriggerObserver::Use(\"%1\");\n", g_Utility.GetPlayerLog(pPlayer.edict()));

            StartObserving(pPlayer, !self.IsBSPModel());
        }

        /**
         * Use handler.
         * @param  CBaseEntity@ pActivator Activator entity
         * @param  CBaseEntity@ pCaller    Caller entity
         * @param  USE_TYPE     useType    Use type
         * @param  float        flValue    Use value
         * @return void
         */
        void Use(CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue)
        {
            if (pActivator is null or !pActivator.IsPlayer()) {
                return;
            }

            CBasePlayer@ pPlayer = cast<CBasePlayer@>(pActivator);
            if (!pPlayer.IsConnected()) {
                return;
            }

            g_Game.AlertMessage(at_aiconsole, "CTriggerObserver::Use(\"%1\", %2, %3, %4);\n", g_Utility.GetPlayerLog(pPlayer.edict()), null, useType, flValue);

            switch (useType) {
                case USE_ON:
                    StartObserving(pPlayer, !self.pev.SpawnFlagBitSet(FLAG_NO_SAVE_POSITION));
                    break;

                case USE_OFF:
                    StopObserving(pPlayer);
                    break;

                case USE_TOGGLE:
                    pPlayer.GetObserver().IsObserver()
                        ? StopObserving(pPlayer)
                        : StartObserving(pPlayer, !self.pev.SpawnFlagBitSet(FLAG_NO_SAVE_POSITION))
                    ;
                    break;
            }
        }
    }

    /**
     * Start observer mode for a player.
     * @param  CBasePlayer@ pPlayer       Player entity
     * @param  bool         fSavePosition Save the player's current position, so the player can be placed back there when they stop observing
     * @return void
     */
    void StartObserving(CBasePlayer@ pPlayer, bool fSavePosition = false)
    {
        if (pPlayer is null or !pPlayer.IsPlayer() or !pPlayer.IsConnected()) {
            return;
        }

        g_Game.AlertMessage(at_aiconsole, "CTriggerObserver::StartObserving(\"%1\", %2);\n", g_Utility.GetPlayerLog(pPlayer.edict()), fSavePosition);

        CustomKeyvalues@ pCustom = pPlayer.GetCustomKeyvalues();
        CustomKeyvalue pCustomIsObserving(pCustom.GetKeyvalue("$i_is_observer"));
        CustomKeyvalue pCustomObserverPriorOrigin(pCustom.GetKeyvalue("$v_observer_prior_origin"));
        CustomKeyvalue pCustomObserverPriorAngles(pCustom.GetKeyvalue("$v_observer_prior_angles"));

        if (pPlayer.GetObserver().IsObserver()) {
            g_Game.AlertMessage(at_logged, "\"%1\" cannot start observing: Already is observing.\n", g_Utility.GetPlayerLog(pPlayer.edict()));
            return;
        }

        if (fSavePosition) {
            pPlayer.KeyValue("$i_is_observer", eObserverState::onThenResumeOrigin);
            g_Game.AlertMessage(at_logged, "\"%1\" has started observing, and will be returned to %2 %3 %4 when finished.\n", g_Utility.GetPlayerLog(pPlayer.edict()), pPlayer.pev.origin.x, pPlayer.pev.origin.y, pPlayer.pev.origin.z);
        } else {
            pPlayer.KeyValue("$i_is_observer", eObserverState::onThenRespawn);
            g_Game.AlertMessage(at_logged, "\"%1\" has started observing, and will be respawned when finished.\n", g_Utility.GetPlayerLog(pPlayer.edict()));
        }

        pPlayer.GetObserver().StartObserver(pPlayer.pev.origin, pPlayer.pev.angles, false);
        pPlayer.pev.nextthink = (g_Engine.time + (ENT_LOOP_INTERVAL * 2));

        Messager( pPlayer, 1 );
        
        pCustom.SetKeyvalue("$v_observer_prior_origin", pPlayer.pev.origin);
        pCustom.SetKeyvalue("$v_observer_prior_angles", pPlayer.pev.angles);
    }

    /**
     * Stop observer mode for a player.
     * @param  CBasePlayer@ pPlayer Player entity
     * @return void
     */
    void StopObserving(CBasePlayer@ pPlayer, bool fIgnoreSavedPosition = false)
    {
        if (pPlayer is null or !pPlayer.IsPlayer() or !pPlayer.IsConnected()) {
            return;
        }

        g_Game.AlertMessage(at_aiconsole, "CTriggerObserver::StopObserving(\"%1\", %2);\n", g_Utility.GetPlayerLog(pPlayer.edict()), fIgnoreSavedPosition);

        CustomKeyvalues@ pCustom = pPlayer.GetCustomKeyvalues();
        CustomKeyvalue pCustomIsObserving(pCustom.GetKeyvalue("$i_is_observer"));
        CustomKeyvalue pCustomObserverPriorOrigin(pCustom.GetKeyvalue("$v_observer_prior_origin"));
        CustomKeyvalue pCustomObserverPriorAngles(pCustom.GetKeyvalue("$v_observer_prior_angles"));

        bool fResumePosition = (pCustomIsObserving.GetInteger() == 2);

        if (!pPlayer.GetObserver().IsObserver()) {
            g_Game.AlertMessage(at_logged, "\"%1\" cannot finish observing: Isn't current observing.\n", g_Utility.GetPlayerLog(pPlayer.edict()));
            return;
        }

        pPlayer.GetObserver().StopObserver(!fResumePosition);

        if (
            !fIgnoreSavedPosition
            && fResumePosition
            && pCustomObserverPriorOrigin.Exists()
            && pCustomObserverPriorAngles.Exists()
        ) {
            pPlayer.KeyValue("$i_is_observer", eObserverState::leavingToResumeOrigin);
            g_Game.AlertMessage(at_logged, "\"%1\" has finished observing, and will be returned to %2 %3 %4.\n", g_Utility.GetPlayerLog(pPlayer.edict()), pPlayer.pev.origin.x, pPlayer.pev.origin.y, pPlayer.pev.origin.z);
        } else {
            pPlayer.KeyValue("$i_is_observer", eObserverState::off);
            g_PlayerFuncs.RespawnPlayer(pPlayer, true, true);
            g_Game.AlertMessage(at_logged, "\"%1\" has finished observing, and will be respawned.\n", g_Utility.GetPlayerLog(pPlayer.edict()));
        }

        pPlayer.pev.nextthink = (g_Engine.time + 0.01);
    }

    /**
     * Global player observer handler.
     * @return void
     */
    void ObserverThink()
    {
        for (int i = 1; i <= g_Engine.maxClients; i++) {
            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex(i);
            if (pPlayer is null or !pPlayer.IsPlayer() or !pPlayer.IsConnected()) {
                continue;
            }

            CustomKeyvalues@ pCustom = pPlayer.GetCustomKeyvalues();
            CustomKeyvalue pCustomIsObserving(pCustom.GetKeyvalue("$i_is_observer"));
            if (pCustomIsObserving.GetInteger() == 3) {
                CustomKeyvalue pCustomObserverPriorOrigin(pCustom.GetKeyvalue("$v_observer_prior_origin"));
                CustomKeyvalue pCustomObserverPriorAngles(pCustom.GetKeyvalue("$v_observer_prior_angles"));

                if (pCustomObserverPriorOrigin.Exists() && pCustomObserverPriorAngles.Exists()) {
                    g_EntityFuncs.SetOrigin(pPlayer, pCustomObserverPriorOrigin.GetVector());
                    pPlayer.pev.angles      = pCustomObserverPriorAngles.GetVector();
                    pPlayer.pev.fixangle    = FAM_FORCEVIEWANGLES;
                }

                pPlayer.pev.nextthink = (g_Engine.time + 0.01);
                pPlayer.KeyValue("$i_is_observer", eObserverState::off);
                continue;
            }

            if (!pPlayer.GetObserver().IsObserver()) {
                continue;
            }

            if ((pPlayer.pev.button & IN_ALT1) != 0) {
                StopObserving(pPlayer);
                continue;
            }

            // Show the binded key in the center just in case
            g_PlayerFuncs.PrintKeyBindingString( pPlayer, "+alt1");
            Messager( pPlayer, 0 );
            
            pPlayer.pev.nextthink = (g_Engine.time + (ENT_LOOP_INTERVAL * 2));
        }
    }

/*
    Let players see a custom language choosed by its own if the plugin multi_language is installed otherwise just show english for everyone -Mikk
    https://github.com/Mikk155/Sven-Co-op/blob/main/scripts/plugins/mikk/multi_language.as
*/
	void Messager( CBasePlayer@ pPlayer, int mode )
	{
        HUDTextParams sHudTextObserverExitReminder;

        sHudTextObserverExitReminder.channel        = 3;
        sHudTextObserverExitReminder.x              = -1;
        sHudTextObserverExitReminder.y              = 0.9;
        sHudTextObserverExitReminder.effect         = 1;
        sHudTextObserverExitReminder.r1             = 100;
        sHudTextObserverExitReminder.g1             = 100;
        sHudTextObserverExitReminder.b1             = 100;
        sHudTextObserverExitReminder.r2             = 240;
        sHudTextObserverExitReminder.g2             = 240;
        sHudTextObserverExitReminder.b2             = 240;
        sHudTextObserverExitReminder.fadeinTime     = 0;
        sHudTextObserverExitReminder.fadeoutTime    = 0;
        sHudTextObserverExitReminder.holdTime       = (ENT_LOOP_INTERVAL * 3);
        sHudTextObserverExitReminder.fxTime         = 0.1;
        
        // Gets their values from multi-language plugin
        CustomKeyvalues@ ckLenguage = pPlayer.GetCustomKeyvalues();
        CustomKeyvalue ckLenguageIs = ckLenguage.GetKeyvalue("$f_lenguage");
        int iLanguage = int(ckLenguageIs.GetFloat());
    /*
        Languages:
        Value of 0 or higher than 7 mean english.-
        1 = Spanish
        2 = Portuguese PT/BR
        3 = German
        4 = French
        5 = Italian
        6 = Esperanto
    */
        // Shows the proper language
        if( mode == 0 )
        {
            if(iLanguage == 1 ) // Spanish
            {
                g_PlayerFuncs.HudMessage( pPlayer, sHudTextObserverExitReminder, "Presiona +alt1 para salir del modo espectador.\nTu letra bindeada es mostrada en tu pantalla.\n" );
            }
            else if(iLanguage == 2 ) // Portuguese
            {
                g_PlayerFuncs.HudMessage( pPlayer, sHudTextObserverExitReminder, "Press +alt1 to leave observer mode.\nYour binded key is shown in the screen\n" );
            }
            else if(iLanguage == 3 ) // German
            {
                g_PlayerFuncs.HudMessage( pPlayer, sHudTextObserverExitReminder, "Press +alt1 to leave observer mode.\nYour binded key is shown in the screen\n" );
            }
            else if(iLanguage == 4 ) // French
            {
                g_PlayerFuncs.HudMessage( pPlayer, sHudTextObserverExitReminder, "Press +alt1 to leave observer mode.\nYour binded key is shown in the screen\n" );
            }
            else if(iLanguage == 5 ) // Italian
            {
                g_PlayerFuncs.HudMessage( pPlayer, sHudTextObserverExitReminder, "Press +alt1 to leave observer mode.\nYour binded key is shown in the screen\n" );
            }
            else if(iLanguage == 6 ) // Esperanto
            {
                g_PlayerFuncs.HudMessage( pPlayer, sHudTextObserverExitReminder, "Press +alt1 to leave observer mode.\nYour binded key is shown in the screen\n" );
            }
            else // Anything else = English
            {
                g_PlayerFuncs.HudMessage( pPlayer, sHudTextObserverExitReminder, "Press +alt1 to leave observer mode.\nYour binded key is shown in the screen\n" );
            }
        }else
        if( mode == 1 )
        {
            if(iLanguage == 1 ) // Spanish
            {
                g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "* Presiona ATAQUE TERCIARIO para salir del modo espectador.\n");
                g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "* Esto normalmente se hace presionando el boton del medio (la ruedita) de tu raton.\n");
            }
            else if(iLanguage == 2 ) // Portuguese
            {
                g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "* Press TERTIARY ATTACK to leave observer mode.\n");
                g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "* This is usually done by pressing the MIDDLE BUTTON (wheel) of your mouse.\n");
            }
            else if(iLanguage == 3 ) // German
            {
                g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "* Press TERTIARY ATTACK to leave observer mode.\n");
                g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "* This is usually done by pressing the MIDDLE BUTTON (wheel) of your mouse.\n");
            }
            else if(iLanguage == 4 ) // French
            {
                g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "* Press TERTIARY ATTACK to leave observer mode.\n");
                g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "* This is usually done by pressing the MIDDLE BUTTON (wheel) of your mouse.\n");
            }
            else if(iLanguage == 5 ) // Italian
            {
                g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "* Press TERTIARY ATTACK to leave observer mode.\n");
                g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "* This is usually done by pressing the MIDDLE BUTTON (wheel) of your mouse.\n");
            }
            else if(iLanguage == 6 ) // Esperanto
            {
                g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "* Press TERTIARY ATTACK to leave observer mode.\n");
                g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "* This is usually done by pressing the MIDDLE BUTTON (wheel) of your mouse.\n");
            }
            else // Anything else = English
            {
                g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "* Press TERTIARY ATTACK to leave observer mode.\n");
                g_PlayerFuncs.ClientPrint(pPlayer, HUD_PRINTTALK, "* This is usually done by pressing the MIDDLE BUTTON (wheel) of your mouse.\n");
            }
        }
    }
}
