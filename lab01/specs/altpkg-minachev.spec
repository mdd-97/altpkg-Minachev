Name: altpkg-minachev
Version: 1.0
Release: alt2
Summary: Prints student name, group and lab number
License: GPL-2.0-or-later
Group: Development/Other
BuildArch: noarch
Source0: %name.sh

%description
Shell script that prints the student's surname, group and lab number.
Built for laboratory work 1.

%install
install -D -m 0755 %SOURCE0 %buildroot%_bindir/%name

%files
%_bindir/%name

%changelog
* Wed Sep 30 2026 Damir Minachev <mdd97@yandex.ru> 1.0-alt2
- Add shell script printing student info

* Wed Sep 30 2026 Damir Minachev <mdd97@yandex.ru> 1.0-alt1
- Initial build
