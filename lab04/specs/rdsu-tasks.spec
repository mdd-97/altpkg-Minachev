Name: rdsu-tasks
Version: 1.0
Release: alt1
Summary: Shell task list for the RDSU practical work
License: MIT
Group: Office
Source0: rdsu-tasks
BuildArch: noarch

%description
A task list with a dialog menu and a command-line interface.

%install
install -D -m755 %SOURCE0 %buildroot%_bindir/rdsu-tasks

%files
%_bindir/rdsu-tasks

%changelog
* Mon Nov 23 2026 Damir Minachev <mdd97@yandex.ru> 1.0-alt1
- Add task list application.
