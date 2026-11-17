Name: rdsu-args
Version: 1.0
Release: alt1
Summary: Argument printing example for RDSU
License: MIT
Group: Development/C
Source: %name-%version.tar.gz
BuildRequires: gcc make

%description
An example of linking a multi-file C program with static and shared libraries.

%prep
%setup -q

%build
%make_build -j1 CFLAGS="%optflags"

%install
install -Dpm0755 rdsu-args-static %buildroot%_bindir/rdsu-args-static
install -Dpm0755 rdsu-args-shared %buildroot%_bindir/rdsu-args-shared
install -Dpm0755 librdsuargs.so %buildroot%_libdir/librdsuargs.so

%files
%_bindir/rdsu-args-static
%_bindir/rdsu-args-shared
%_libdir/librdsuargs.so

%changelog
* Wed Nov 18 2026 Damir Minachev <mdd-97@users.noreply.github.com> 1.0-alt1
- Initial package for laboratory work 3.
