/* 
 *      Copyright 2011 Julien Lavergne <gilir@ubuntu.com>
 *
 *      This program is free software; you can redistribute it and/or modify
 *      it under the terms of the GNU General Public License as published by
 *      the Free Software Foundation; either version 2 of the License, or
 *      (at your option) any later version.
 *
 *      This program is distributed in the hope that it will be useful,
 *      but WITHOUT ANY WARRANTY; without even the implied warranty of
 *      MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *      GNU General Public License for more details.
 *
 *      You should have received a copy of the GNU General Public License
 *      along with this program; if not, write to the Free Software
 *      Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 *      MA 02110-1301, USA.
*/

/* 
   TODO packagekit handler (GUI and stuff) ?
   TODO Use wnck for managing launching applications ?
*/
using Gee;

namespace Lxsession {

public class AppObject: GLib.Object {

    /* Core App Object, all other App objects should inherent from it
       You should not do an instance of it, use GenericAppObject if you want
       a usefull Object
    */

    private Pid pid;

    public string name { get; set;}
    public string[] command { get; set;}
    public bool guard { get; set; default = false;}
    public string application_type { get; set;}

    public AppObject() {

    }

    public void launch () {
        if (this.name != null)
        {
            try {
                Process.spawn_async (
                             null,
                             this.command,
                             null,
                             SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                             null,
                             out pid);
                ChildWatch.add(pid, callback_pid);

                message ("Launching %s %s %s", this.name, this.command[1], this.command[2]);
            }
            catch (SpawnError err){
                warning (err.message);
            }
        }

    }


    private void callback_pid(Pid pid, int status) {
        /* Help :  http://en.wikipedia.org/wiki/Signal_(computing) 
                   http://valadoc.org/glib-2.0/GLib.ProcessSignal.html
        */
        message("%s exit with this type of exit: %i", this.name, status);

        Process.close_pid (pid);

        if (this.guard == true)
        { 
            switch (status)
            {
                case 0:
                    message("Exit normal, don't reload");
                    break;
                case 15:
                    message("Exit by the user, don't reload");
                    break;
                case 256:
                    message("Exit normal, don't reload");
                    break;
                default:
                    message("Exit not normal, reload");
                    this.launch();
                    break;

		    }
        }
    }
}


public class GenericAppObject: AppObject
{

    public GenericAppObject(AppType app_type)
    {
        this.name = app_type.name;
        this.command = app_type.command;
        this.guard = app_type.guard;
        this.application_type = app_type.application_type;
    }
}   

public class SimpleAppObject: AppObject
{

    public SimpleAppObject(string app_name)
    {
        this.name = app_name;
        this.command = {app_name};
        this.guard = false;
        this.application_type = "";
    }
} 

public class WindowManagerApp: SimpleAppObject
{
    public WindowManagerApp (string wm_command)
    {

        base(wm_command);

        if (wm_command == "wm_safe") 
        {
            this.name = "wm_safe";
            this.command = {find_window_manager()};
        }
        else
        {
            this.name = wm_command;
            this.command = {wm_command};
        }
        this.guard = true;

    }

    private string find_window_manager()
    {

        var wm_list = new ArrayList<string> ();

        wm_list.add("openbox-lxde");
        wm_list.add("openbox-lubuntu");
        wm_list.add("openbox");
        wm_list.add("compiz");
        wm_list.add("kwin");
        wm_list.add("mutter");
        wm_list.add("fluxbox");
        wm_list.add("metacity");
        wm_list.add("xfwin");
        wm_list.add("matchbox");

        string return_value = "";

        foreach (string i in wm_list)
        {
            if (Environment.find_program_in_path(i) == null)
            {
                message ("Finding %s",i);
                return_value = i;
                break;
            }
        }

        return return_value;

    }

    private void callback_pid(Pid pid, int status)
    {
        /* Help :  http://en.wikipedia.org/wiki/Signal_(computing) 
                   http://valadoc.org/glib-2.0/GLib.ProcessSignal.html
        */
        stderr.printf("%s exit with this type of exit: %i\n", this.name, status);

        if (status == -1)
        {
            this.name = "wm_safe";
            this.command = {find_window_manager()};
            global_sig.update_window_manager("wm_safe");
        }

        Process.close_pid (pid);

        if (this.guard == true)
        { 

		    switch (status)
            {
                case 0:
                    message("Exit normal, don't reload");
                    break;
                case 15:
                    message("Exit by the user, don't reload");
                    break;
                case 256:
                    message("Exit normal, don't reload");
                    break;
                default:
                    message("Exit not normal, reload");
                    this.launch();
                    break;
		    }
        }
    }
}

public class PanelApp: SimpleAppObject {

    public PanelApp (string panel_command, string panel_session){

        base(panel_command);

        switch (panel_command) 
        {
            case "lxpanel":
                this.name = panel_command;
                if (panel_session != null)
                {
                    string create_command = "lxpanel --profile " + panel_session;
                    this.command = create_command.split_set(" ",0);
                }
                else
                {
                    this.command = {panel_command};
                }
                break;
            default:
                string[] create_command = panel_command.split_set(" ",0);
                this.name = create_command[0];
                this.command = create_command;
                break;
        }
        this.guard = true;

    }
}

public class ScreensaverApp: SimpleAppObject {

    public ScreensaverApp (string screensaver_command){

        base(screensaver_command);

        switch (screensaver_command) 
        {
            case "xscreensaver":
                this.name = screensaver_command;
                string create_command = "xscreensaver -no-splash";
                this.command = create_command.split_set(" ",0);
                break;
            default:
                string[] create_command = screensaver_command.split_set(" ",0);
                this.name = create_command[0];
                this.command = create_command;
                break;
        }
        this.guard = true;

    }
}

public class PowermanagerApp: SimpleAppObject {

    public PowermanagerApp (string powermanager_command){

        base(powermanager_command);

        switch (powermanager_command) 
        {
            case "auto":
                /* If we are on a laptop, we need a power manager, try to start xfce one */
                /* If we are not on a laptop, assume we don't need power management */
                if (detect_laptop())
                {
                    string create_command = "xfce-power-management";
                    this.name = "xfce-power-management";
                    this.command = create_command.split_set(" ",0);
                }

                break;
            case "no":
                this.name = "power_manager_off";
                break;
            default:
                string[] create_command = powermanager_command.split_set(" ",0);
                this.name = create_command[0];
                this.command = create_command;
                break;
        }
        this.guard = true;

    }
}

public class FilemanagerApp: SimpleAppObject {

    public FilemanagerApp (string filemanager_command,
                           string filemanager_session,
                           string filemanager_extras )
    {

        base(filemanager_command);

        switch (filemanager_command) 
        {
            case "pcmanfm":
                this.name = filemanager_command;
                if (filemanager_session != null)
                {
                    string create_command = "pcmanfm --desktop --profile " + filemanager_session + filemanager_extras;
                    this.command = create_command.split_set(" ",0);
                }
                else
                {
                    this.command = {filemanager_command};
                }
                break;
            case "nautilus":
                string create_command = "nautilus" + " -n" + filemanager_extras;
                this.command = create_command.split_set(" ",0);
                break;
            default:
                string[] create_command = filemanager_command.split_set(" ",0);
                this.name = create_command[0];
                this.command = create_command;
                break;
        }
        this.guard = true;

    }
}

public class PolkitApp: SimpleAppObject {

    public PolkitApp (string polkit_command){

        base(polkit_command);

        switch (polkit_command) 
        {
            case "gnome":
                this.name = "polkit-gnome-authentication-agent-1";
                string create_command = "/usr/lib/policykit-1-gnome/polkit-gnome-authentication-agent-1";
                this.command = create_command.split_set(" ",0);
                break;
            case "lxpolkit":
                this.name = "lxpolkit";
                string create_command = "lxpolkit";
                this.command = create_command.split_set(" ",0);
                break;
        }
        this.guard = true;

    }
}

public class NetworkGuiApp: SimpleAppObject
{
    public NetworkGuiApp (string network_command)
    {
        base(network_command);
        switch (network_command)
        {
            case "no":
                /* Don't start anything */
                break;
            case "auto":
                /* If we are on a laptop, assume we need a GUI, and try to find one, starting with nm-applet */
                /* If you are not on a laptop, assume we don't need any GUI */
                if (detect_laptop())
                /* TODO Update the settings, to not test every time lxsession is started */
                {
                     if (Environment.find_program_in_path("nm-applet") == null)
                     {
                         this.name = "nm-applet";
                         string create_command = "nm-applet";
                         this.command = create_command.split_set(" ",0);
                         break;
                     }
                     else if (Environment.find_program_in_path("wicd") == null)
                     {
                         this.name = "wicd";
                         string create_command = "wicd";
                         this.command = create_command.split_set(" ",0);
                         break;
                     }
                 }
                 break;
            default:
                string[] create_command = network_command.split_set(" ",0);
                this.name = create_command[0];
                this.command = create_command;
                break;
        }
        this.guard = true;
    }
}

public class AudioManagerApp: SimpleAppObject {

    public AudioManagerApp (string audiomanager_command){

        base(audiomanager_command);

        switch (audiomanager_command)
        {
            case "alsamixer":
                this.name = "alsamixer";
                string create_command = "xterm -e alsamixer";
                this.command = create_command.split_set(" ",0);
                break;
            default:
                string[] create_command = audiomanager_command.split_set(" ",0);
                this.name = create_command[0];
                this.command = create_command;
                break;
        }
    }
}

public class QuitManagerApp: SimpleAppObject {

    public QuitManagerApp (string quitmanager_command){

        base(quitmanager_command);

        switch (quitmanager_command)
        {
            default:
                string[] create_command = quitmanager_command.split_set(" ",0);
                this.name = create_command[0];
                this.command = create_command;
                break;
        }
    }
}

public class WorkspaceManagerApp: SimpleAppObject {

    public WorkspaceManagerApp (string workspacemanager_command){

        base(workspacemanager_command);

        switch (workspacemanager_command)
        {
            case "obconf":
                this.name = "obconf";
                string create_command = "obconf --tab 6";
                this.command = create_command.split_set(" ",0);
                break;
            default:
                string[] create_command = workspacemanager_command.split_set(" ",0);
                this.name = create_command[0];
                this.command = create_command;
                break;
        }
    }
}

public class LauncherManagerApp: SimpleAppObject {

    public LauncherManagerApp (string launchermanager_command){

        base(launchermanager_command);

        switch (launchermanager_command)
        {
            default:
                string[] create_command = launchermanager_command.split_set(" ",0);
                this.name = create_command[0];
                this.command = create_command;
                break;
        }
    }
}

public class TerminalManagerApp: SimpleAppObject {

    public TerminalManagerApp (string terminalmanager_command){

        base(terminalmanager_command);

        switch (terminalmanager_command)
        {
            case "lxterminal":
                this.name = "lxterminal";
                string create_command = "lxterminal -e";
                this.command = create_command.split_set(" ",0);
                break;
            default:
                string[] create_command = terminalmanager_command.split_set(" ",0);
                this.name = create_command[0];
                this.command = create_command;
                break;
        }
    }
}

}
