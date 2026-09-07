/* Trimmed from vala-dbus-binding-tool output to the members Peek uses. */
using GLib;

namespace Freedesktop {

	[DBus (name = "org.freedesktop.DBus", timeout = 120000)]
	public interface DBus : GLib.Object {

		[DBus (name = "StartServiceByName")]
		public abstract uint start_service_by_name(string param0, uint param1) throws DBusError, IOError;

		[DBus (name = "NameHasOwner")]
		public abstract bool name_has_owner(string param0) throws DBusError, IOError;
	}
}
