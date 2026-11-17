Name: show
Version: 1.0
Release: alt1
Summary: Ncurses terminal demonstration program
License: Unknown
Group: Other
Source: %{name}-%{version}.tar.gz
BuildRequires: libncurses-devel

%description
A terminal demonstration program using ncurses.

%prep
%setup -q

%build
%make_build

%install
install -D -m 0755 Show "%{buildroot}%{_bindir}/Show"

%files
%{_bindir}/Show

%changelog
* Tue Nov 17 2026 Damir Minachev <mdd97@yandex.ru> 1.0-alt1
- Initial package.
