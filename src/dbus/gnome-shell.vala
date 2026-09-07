/* Trimmed from vala-dbus-binding-tool output to the members Peek uses. */
using GLib;

namespace Gnome {

	[DBus (name = "org.gnome.Shell", timeout = 120000)]
	public interface Shell : GLib.Object {

		[DBus (name = "ShellVersion")]
		public abstract string shell_version { owned get; }
	}
}
