Name: rdsu-args
Version: 1.0
Release: alt2
Summary: Argument printing example for RDSU
License: MIT
Group: Development/C
Source: %name-%version.tar.gz
BuildRequires: gcc make

%description
An example of linking a multi-file C program with static and shared libraries.

%package -n librdsuargs
Summary: Shared library for the RDSU argument example
Group: System/Libraries

%description -n librdsuargs
Shared functions and counter used by the dynamically linked example.

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

%files -n librdsuargs
%_libdir/librdsuargs.so

%changelog
* Wed Nov 25 2026 Damir Minachev <mdd-97@users.noreply.github.com> 1.0-alt2
- Split shared library to preserve automatic inter-package ELF dependency.

* Wed Nov 18 2026 Damir Minachev <mdd-97@users.noreply.github.com> 1.0-alt1
- Initial package for laboratory work 3.
