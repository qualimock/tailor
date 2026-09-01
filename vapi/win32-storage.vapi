[CCode (cheader_filename = "windows.h,setupapi.h,winioctl.h,sysinfoapi.h,dbt.h,shellapi.h")]
namespace Win32 {

	[CCode (cname = "INVALID_HANDLE_VALUE")]
	public static void* invalid_handle_value;

	[CCode (cname = "GetLastError")]
	public static uint32 get_last_error ();

	[CCode (cname = "SYSTEM_INFO", has_type_id = false)]
	public struct SystemInfo {
		[CCode (cname = "wProcessorArchitecture")]
		public uint16 processor_architecture;
	}

	[CCode (cname = "GetNativeSystemInfo")]
	public static void get_native_system_info (out SystemInfo system_info);

	[CCode (cname = "PROCESSOR_ARCHITECTURE_AMD64")]
	public const uint16 PROCESSOR_ARCHITECTURE_AMD64;

	[CCode (cname = "PROCESSOR_ARCHITECTURE_ARM64")]
	public const uint16 PROCESSOR_ARCHITECTURE_ARM64;

	[CCode (cname = "PROCESSOR_ARCHITECTURE_INTEL")]
	public const uint16 PROCESSOR_ARCHITECTURE_INTEL;

	[CCode (cname = "PROCESSOR_ARCHITECTURE_ARM")]
	public const uint16 PROCESSOR_ARCHITECTURE_ARM;

	[CCode (cname = "GUID", has_type_id = false)]
	public struct Guid {
		[CCode (cname = "Data1")]
		public uint32 data1;
		[CCode (cname = "Data2")]
		public uint16 data2;
		[CCode (cname = "Data3")]
		public uint16 data3;
		[CCode (cname = "Data4")]
		public uint8 data4[8];
	}

	[CCode (cname = "GUID_DEVINTERFACE_DISK")]
	public static Guid guid_devinterface_disk;

	[Flags]
	[CCode (cname = "DWORD", cprefix = "DIGCF_", has_type_id = false)]
	public enum DeviceInfoFlags {
		PRESENT,
		DEVICEINTERFACE
	}

	[CCode (cname = "SP_DEVICE_INTERFACE_DATA", has_type_id = false)]
	public struct DeviceInterfaceData {
		[CCode (cname = "cbSize")]
		public uint32 cb_size;
		[CCode (cname = "InterfaceClassGuid")]
		public Guid interface_class_guid;
		[CCode (cname = "Flags")]
		public uint32 flags;
		[CCode (cname = "Reserved")]
		public size_t reserved;
	}

	[CCode (cname = "SetupDiGetClassDevsW")]
	public static void* get_class_devs (
		Guid* class_guid,
		string? enumerator,
		void* hwnd_parent,
		DeviceInfoFlags flags
	);

	[CCode (cname = "SetupDiEnumDeviceInterfaces")]
	public static bool enum_device_interfaces (
		void* device_info_set,
		void* device_info_data,
		Guid* interface_class_guid,
		uint32 member_index,
		ref DeviceInterfaceData device_interface_data
	);

	[CCode (cname = "SetupDiGetDeviceInterfaceDetailW")]
	public static bool get_device_interface_detail (
		void* device_info_set,
		DeviceInterfaceData* device_interface_data,
		void* device_interface_detail_data,
		uint32 device_interface_detail_data_size,
		out uint32 required_size,
		void* device_info_data
	);

	[CCode (cname = "SP_DEVICE_INTERFACE_DETAIL_DATA_W", has_type_id = false)]
	public struct DeviceInterfaceDetailData {
		[CCode (cname = "cbSize")]
		public uint32 cb_size;
	}

	[CCode (cname = "SetupDiDestroyDeviceInfoList")]
	public static bool destroy_device_info_list (void* device_info_set);

	[CCode (cname = "CreateFileA")]
	public static void* create_file (
		string file_name,
		uint32 desired_access,
		uint32 share_mode,
		void* security_attributes,
		uint32 creation_disposition,
		uint32 flags_and_attributes,
		void* template_file
	);

	[CCode (cname = "GENERIC_READ")]
	public const uint32 GENERIC_READ;

	[CCode (cname = "GENERIC_WRITE")]
	public const uint32 GENERIC_WRITE;

	[CCode (cname = "FILE_SHARE_READ")]
	public const uint32 FILE_SHARE_READ;

	[CCode (cname = "FILE_SHARE_WRITE")]
	public const uint32 FILE_SHARE_WRITE;

	[CCode (cname = "OPEN_EXISTING")]
	public const uint32 OPEN_EXISTING;

	[CCode (cname = "CloseHandle")]
	public static bool close_handle (void* handle);

	[CCode (cname = "WideCharToMultiByte")]
	public static int wide_char_to_multi_byte (
		uint32 code_page,
		uint32 flags,
		void* wide_char_str,
		int wide_char_count,
		void* multi_byte_str,
		int multi_byte_size,
		void* default_char,
		void* used_default_char
	);

	[CCode (cname = "CP_UTF8")]
	public const uint32 CP_UTF8;

	[CCode (cname = "DeviceIoControl")]
	public static bool device_io_control (
		void* device,
		uint32 io_control_code,
		void* in_buffer,
		uint32 in_buffer_size,
		void* out_buffer,
		uint32 out_buffer_size,
		out uint32 bytes_returned,
		void* overlapped
	);

	[CCode (cname = "IOCTL_STORAGE_GET_DEVICE_NUMBER")]
	public const uint32 IOCTL_STORAGE_GET_DEVICE_NUMBER;

	[CCode (cname = "STORAGE_DEVICE_NUMBER", has_type_id = false)]
	public struct StorageDeviceNumber {
		[CCode (cname = "DeviceType")]
		public uint32 device_type;
		[CCode (cname = "DeviceNumber")]
		public uint32 device_number;
		[CCode (cname = "PartitionNumber")]
		public uint32 partition_number;
	}

	[CCode (cname = "IOCTL_DISK_GET_DRIVE_GEOMETRY_EX")]
	public const uint32 IOCTL_DISK_GET_DRIVE_GEOMETRY_EX;

	[CCode (cname = "IOCTL_DISK_UPDATE_PROPERTIES")]
	public const uint32 IOCTL_DISK_UPDATE_PROPERTIES;

	[SimpleType]
	[CCode (cname = "LARGE_INTEGER", has_type_id = false)]
	public struct LargeInteger {
		[CCode (cname = "QuadPart")]
		public int64 quad_part;
	}

	[CCode (cname = "SetFilePointerEx")]
	public static bool set_file_pointer (void* handle, LargeInteger distance_to_move, void* new_pointer, uint32 move_method);

	[CCode (cname = "FILE_BEGIN")]
	public const uint32 FILE_BEGIN;

	[CCode (cname = "DISK_GEOMETRY_EX", has_type_id = false)]
	public struct DiskGeometryEx {
		[CCode (cname = "Geometry")]
		public uint8 geometry[24];
		[CCode (cname = "DiskSize.QuadPart")]
		public int64 disk_size;
	}

	[CCode (cname = "IOCTL_STORAGE_QUERY_PROPERTY")]
	public const uint32 IOCTL_STORAGE_QUERY_PROPERTY;

	[CCode (cname = "FSCTL_LOCK_VOLUME")]
	public const uint32 FSCTL_LOCK_VOLUME;

	[CCode (cname = "FSCTL_DISMOUNT_VOLUME")]
	public const uint32 FSCTL_DISMOUNT_VOLUME;

	[CCode (cname = "STORAGE_PROPERTY_ID", cprefix = "", has_type_id = false)]
	public enum StoragePropertyId {
		[CCode (cname = "StorageDeviceProperty")]
		DEVICE_PROPERTY
	}

	[CCode (cname = "STORAGE_QUERY_TYPE", cprefix = "", has_type_id = false)]
	public enum StorageQueryType {
		[CCode (cname = "PropertyStandardQuery")]
		STANDARD_QUERY
	}

	[CCode (cname = "STORAGE_PROPERTY_QUERY", has_type_id = false)]
	public struct StoragePropertyQuery {
		[CCode (cname = "PropertyId")]
		public StoragePropertyId property_id;
		[CCode (cname = "QueryType")]
		public StorageQueryType query_type;
		[CCode (cname = "AdditionalParameters")]
		public uint8 additional_parameters[1];
	}

	[CCode (cname = "STORAGE_BUS_TYPE", cprefix = "", has_type_id = false)]
	public enum StorageBusType {
		[CCode (cname = "BusTypeUsb")]
		USB
	}

	[CCode (cname = "STORAGE_DEVICE_DESCRIPTOR", has_type_id = false)]
	public struct StorageDeviceDescriptor {
		[CCode (cname = "Version")]
		public uint32 version;
		[CCode (cname = "Size")]
		public uint32 size;
		[CCode (cname = "DeviceType")]
		public uint8 device_type;
		[CCode (cname = "DeviceTypeModifier")]
		public uint8 device_type_modifier;
		[CCode (cname = "RemovableMedia")]
		public bool removable_media;
		[CCode (cname = "CommandQueueing")]
		public bool command_queueing;
		[CCode (cname = "VendorIdOffset")]
		public uint32 vendor_id_offset;
		[CCode (cname = "ProductIdOffset")]
		public uint32 product_id_offset;
		[CCode (cname = "ProductRevisionOffset")]
		public uint32 product_revision_offset;
		[CCode (cname = "SerialNumberOffset")]
		public uint32 serial_number_offset;
		[CCode (cname = "BusType")]
		public StorageBusType bus_type;
		[CCode (cname = "RawPropertiesLength")]
		public uint32 raw_properties_length;
	}

	[CCode (cname = "FindFirstVolumeA")]
	public static void* find_first_volume (
		[CCode (array_length = false)] uint8[] volume_name_buffer,
		uint32 buffer_length
	);

	[CCode (cname = "FindNextVolumeA")]
	public static bool find_next_volume (
		void* find_handle,
		[CCode (array_length = false)] uint8[] volume_name_buffer,
		uint32 buffer_length
	);

	[CCode (cname = "FindVolumeClose")]
	public static bool find_volume_close (void* find_handle);

	[CCode (cname = "GetVolumeInformationA")]
	public static bool get_volume_information (
		string root_path_name,
		void* volume_name_buffer,
		uint32 volume_name_size,
		out uint32 volume_serial_number,
		out uint32 maximum_component_length,
		out uint32 file_system_flags,
		[CCode (array_length = false)] uint8[] file_system_name_buffer,
		uint32 file_system_name_size
	);

	[CCode (cname = "GetLogicalDrives")]
	public static uint32 get_logical_drives ();

	[CCode (cname = "DeleteVolumeMountPointA")]
	public static bool delete_volume_mount_point (string volume_mount_point);

	[CCode (cname = "WNDPROC", has_target = false)]
	public delegate ssize_t WndProc (void* hwnd, uint32 msg, size_t wparam, ssize_t lparam);

	[CCode (cname = "WNDCLASSEXA", has_type_id = false)]
	public struct WndClassEx {
		[CCode (cname = "cbSize")]
		public uint32 cb_size;
		[CCode (cname = "style")]
		public uint32 style;
		[CCode (cname = "lpfnWndProc")]
		public WndProc wnd_proc;
		[CCode (cname = "cbClsExtra")]
		public int cls_extra;
		[CCode (cname = "cbWndExtra")]
		public int wnd_extra;
		[CCode (cname = "hInstance")]
		public void* instance;
		[CCode (cname = "hIcon")]
		public void* icon;
		[CCode (cname = "hCursor")]
		public void* cursor;
		[CCode (cname = "hbrBackground")]
		public void* background;
		[CCode (cname = "lpszMenuName")]
		public unowned string? menu_name;
		[CCode (cname = "lpszClassName")]
		public unowned string class_name;
		[CCode (cname = "hIconSm")]
		public void* icon_sm;
	}

	[CCode (cname = "RegisterClassExA")]
	public static uint16 register_class_ex (WndClassEx* wnd_class);

	[CCode (cname = "GetModuleHandleA")]
	public static void* get_module_handle (string? module_name);

	[CCode (cname = "HWND_MESSAGE")]
	public static void* hwnd_message;

	[CCode (cname = "CreateWindowExA")]
	public static void* create_window_ex (
		uint32 ex_style,
		string class_name,
		string? window_name,
		uint32 style,
		int x, int y, int width, int height,
		void* parent,
		void* menu,
		void* instance,
		void* param
	);

	[CCode (cname = "DefWindowProcA")]
	public static ssize_t def_window_proc (void* hwnd, uint32 msg, size_t wparam, ssize_t lparam);

	[CCode (cname = "POINT", has_type_id = false)]
	public struct Point {
		[CCode (cname = "x")]
		public int32 x;
		[CCode (cname = "y")]
		public int32 y;
	}

	[CCode (cname = "MSG", has_type_id = false)]
	public struct Msg {
		[CCode (cname = "hwnd")]
		public void* hwnd;
		[CCode (cname = "message")]
		public uint32 message;
		[CCode (cname = "wParam")]
		public size_t wparam;
		[CCode (cname = "lParam")]
		public ssize_t lparam;
		[CCode (cname = "time")]
		public uint32 time;
		[CCode (cname = "pt")]
		public Point pt;
	}

	[CCode (cname = "GetMessageA")]
	public static int get_message (Msg* msg, void* hwnd, uint32 filter_min, uint32 filter_max);

	[CCode (cname = "TranslateMessage")]
	public static bool translate_message (Msg* msg);

	[CCode (cname = "DispatchMessageA")]
	public static ssize_t dispatch_message (Msg* msg);

	[CCode (cname = "PostQuitMessage")]
	public static void post_quit_message (int exit_code);

	[CCode (cname = "RegisterDeviceNotificationA")]
	public static void* register_device_notification (void* recipient, void* filter, uint32 flags);

	[CCode (cname = "UnregisterDeviceNotification")]
	public static bool unregister_device_notification (void* handle);

	[CCode (cname = "DEVICE_NOTIFY_WINDOW_HANDLE")]
	public const uint32 DEVICE_NOTIFY_WINDOW_HANDLE;

	[CCode (cname = "DBT_DEVTYP_DEVICEINTERFACE")]
	public const uint32 DBT_DEVTYP_DEVICEINTERFACE;

	[CCode (cname = "DEV_BROADCAST_DEVICEINTERFACE_A", has_type_id = false)]
	public struct DevBroadcastDeviceInterface {
		[CCode (cname = "dbcc_size")]
		public uint32 size;
		[CCode (cname = "dbcc_devicetype")]
		public uint32 device_type;
		[CCode (cname = "dbcc_reserved")]
		public uint32 reserved;
		[CCode (cname = "dbcc_classguid")]
		public Guid class_guid;
		[CCode (cname = "dbcc_name")]
		public uint8 name[1];
	}

	[CCode (cname = "WM_DEVICECHANGE")]
	public const uint32 WM_DEVICECHANGE;

	[CCode (cname = "DBT_DEVICEARRIVAL")]
	public const uint32 DBT_DEVICEARRIVAL;

	[CCode (cname = "DBT_DEVICEREMOVECOMPLETE")]
	public const uint32 DBT_DEVICEREMOVECOMPLETE;

	[CCode (cname = "SHELLEXECUTEINFOA", has_type_id = false)]
	public struct ShellExecuteInfo {
		[CCode (cname = "cbSize")]
		public uint32 cb_size;
		[CCode (cname = "fMask")]
		public uint32 mask;
		[CCode (cname = "hwnd")]
		public void* hwnd;
		[CCode (cname = "lpVerb")]
		public unowned string? verb;
		[CCode (cname = "lpFile")]
		public unowned string file;
		[CCode (cname = "lpParameters")]
		public unowned string? parameters;
		[CCode (cname = "lpDirectory")]
		public unowned string? directory;
		[CCode (cname = "nShow")]
		public int show;
		[CCode (cname = "hInstApp")]
		public void* inst_app;
		[CCode (cname = "lpIDList")]
		public void* id_list;
		[CCode (cname = "lpClass")]
		public unowned string? class_name;
		[CCode (cname = "hkeyClass")]
		public void* key_class;
		[CCode (cname = "dwHotKey")]
		public uint32 hot_key;
		[CCode (cname = "hIcon")]
		public void* icon;
		[CCode (cname = "hProcess")]
		public void* process;
	}

	[CCode (cname = "ShellExecuteExA")]
	public static bool shell_execute_ex (ShellExecuteInfo* exec_info);

	[CCode (cname = "SEE_MASK_NOCLOSEPROCESS")]
	public const uint32 SEE_MASK_NOCLOSEPROCESS;

	[CCode (cname = "SW_HIDE")]
	public const int SW_HIDE;

	[CCode (cname = "GetModuleFileNameA")]
	public static uint32 get_module_file_name (void* module, [CCode (array_length = false)] uint8[] buffer, uint32 size);

	[CCode (cname = "WaitForSingleObject")]
	public static uint32 wait_for_single_object (void* handle, uint32 milliseconds);

	[CCode (cname = "Sleep")]
	public static void sleep_ms (uint32 milliseconds);

	[CCode (cname = "GetExitCodeProcess")]
	public static bool get_exit_code_process (void* process, out uint32 exit_code);

	[CCode (cname = "STARTUPINFOA", has_type_id = false)]
	public struct StartupInfo {
		[CCode (cname = "cb")]
		public uint32 cb;
	}

	[CCode (cname = "PROCESS_INFORMATION", has_type_id = false)]
	public struct ProcessInformation {
		[CCode (cname = "hProcess")]
		public void* process;
		[CCode (cname = "hThread")]
		public void* thread;
		[CCode (cname = "dwProcessId")]
		public uint32 process_id;
		[CCode (cname = "dwThreadId")]
		public uint32 thread_id;
	}

	[CCode (cname = "CreateProcessA")]
	public static bool create_process (
		string? application_name,
		string command_line,
		void* process_attributes,
		void* thread_attributes,
		bool inherit_handles,
		uint32 creation_flags,
		void* environment,
		string? current_directory,
		StartupInfo* startup_info,
		ProcessInformation* process_information
	);

	[CCode (cname = "CreateNamedPipeA")]
	public static void* create_named_pipe (
		string name,
		uint32 open_mode,
		uint32 pipe_mode,
		uint32 max_instances,
		uint32 out_buffer_size,
		uint32 in_buffer_size,
		uint32 default_timeout,
		void* security_attributes
	);

	[CCode (cname = "ConnectNamedPipe")]
	public static bool connect_named_pipe (void* pipe_handle, void* overlapped);

	[CCode (cname = "DisconnectNamedPipe")]
	public static bool disconnect_named_pipe (void* pipe_handle);

	[CCode (cname = "WaitNamedPipeA")]
	public static bool wait_named_pipe (string name, uint32 timeout);

	[CCode (cname = "ReadFile")]
	public static bool read_file (
		void* handle,
		void* buffer,
		uint32 bytes_to_read,
		out uint32 bytes_read,
		void* overlapped
	);

	[CCode (cname = "WriteFile")]
	public static bool write_file (
		void* handle,
		void* buffer,
		uint32 bytes_to_write,
		out uint32 bytes_written,
		void* overlapped
	);

	[CCode (cname = "PIPE_ACCESS_DUPLEX")]
	public const uint32 PIPE_ACCESS_DUPLEX;

	[CCode (cname = "PIPE_TYPE_BYTE")]
	public const uint32 PIPE_TYPE_BYTE;

	[CCode (cname = "PIPE_WAIT")]
	public const uint32 PIPE_WAIT;

	[CCode (cname = "ERROR_PIPE_CONNECTED")]
	public const uint32 ERROR_PIPE_CONNECTED;

	[CCode (cname = "ERROR_CANCELLED")]
	public const uint32 ERROR_CANCELLED;
}
