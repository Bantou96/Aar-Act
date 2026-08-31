_checks_network() {
# =============================================================================
#  5. NETWORK
# =============================================================================
section "5. NETWORK"

# NET-01 Firewall
if svc_active firewalld; then
  add_result "Network" "PASS" "NET-01" "firewalld active" "firewalld actif" "firewalld: running" ""
elif svc_active ufw; then
  add_result "Network" "PASS" "NET-01" "ufw active" "ufw actif" "ufw: running" ""
elif iptables -L INPUT -n 2>/dev/null | grep -qvE "^(Chain|target|$)"; then
  add_result "Network" "WARN" "NET-01" "iptables rules (verify)" "Règles iptables (à vérifier)" "iptables rules found" \
    "Check your iptables rules, or migrate to firewalld."
else
  add_result "Network" "FAIL" "NET-01" "No firewall active" "Aucun pare-feu actif" "No firewall detected" \
    "Enable: 'systemctl enable --now firewalld'"
fi

# NET-02 IP Forwarding
IPF=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "?")
if [[ "$IPF" == "0" ]]; then
  add_result "Network" "PASS" "NET-02" "IP forwarding disabled" "Transfert IP désactivé" "ip_forward=0" ""
else
  add_result "Network" "WARN" "NET-02" "IP forwarding enabled" "Transfert IP activé" "ip_forward=$IPF" \
    "Disable if unused: 'sysctl -w net.ipv4.ip_forward=0'"
fi

# NET-03 ICMP Redirects (accept)
ICR=$(sysctl -n net.ipv4.conf.all.accept_redirects 2>/dev/null || echo "?")
if [[ "$ICR" == "0" ]]; then
  add_result "Network" "PASS" "NET-03" "ICMP redirects disabled" "Redirections ICMP désactivées" "accept_redirects=0" ""
else
  add_result "Network" "FAIL" "NET-03" "ICMP redirects accepted" "Redirections ICMP acceptées" "accept_redirects=$ICR" \
    "Add to /etc/sysctl.d/: 'net.ipv4.conf.all.accept_redirects=0'"
fi

# NET-04 SYN Cookies
SC=$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null || echo "?")
if [[ "$SC" == "1" ]]; then
  add_result "Network" "PASS" "NET-04" "TCP SYN cookies enabled" "SYN cookies TCP activés" "tcp_syncookies=1" ""
else
  add_result "Network" "FAIL" "NET-04" "TCP SYN cookies disabled" "SYN cookies TCP désactivés" "tcp_syncookies=$SC" \
    "Enable: 'sysctl -w net.ipv4.tcp_syncookies=1'"
fi

# NET-05 Dangerous services
DANGEROUS_SVCS=("telnet" "rsh" "rlogin" "ftp" "tftp" "nis" "talk" "chargen" "telnetd" "ftpd")
FOUND_SVCS=()
for svc in "${DANGEROUS_SVCS[@]}"; do
  svc_active "$svc" && FOUND_SVCS+=("$svc") || true
done
if [[ ${#FOUND_SVCS[@]} -eq 0 ]]; then
  add_result "Network" "PASS" "NET-05" "No dangerous services" "Aucun service dangereux" "telnet/ftp/rsh all inactive" ""
else
  add_result "Network" "FAIL" "NET-05" "Dangerous services active" "Services dangereux actifs" "${FOUND_SVCS[*]}" \
    "Disable: 'systemctl disable --now <service>'"
fi

# NET-06 Source routing disabled
SRC_ROUTE=$(sysctl -n net.ipv4.conf.all.accept_source_route 2>/dev/null || echo "?")
if [[ "$SRC_ROUTE" == "0" ]]; then
  add_result "Network" "PASS" "NET-06" "Source routing disabled" "Routage source désactivé" "accept_source_route=0" ""
else
  add_result "Network" "FAIL" "NET-06" "Source routing enabled" "Routage source activé" "accept_source_route=$SRC_ROUTE" \
    "Add: 'net.ipv4.conf.all.accept_source_route=0' to /etc/sysctl.d/"
fi

# NET-07 Send redirects disabled
SEND_REDIR=$(sysctl -n net.ipv4.conf.all.send_redirects 2>/dev/null || echo "?")
if [[ "$SEND_REDIR" == "0" ]]; then
  add_result "Network" "PASS" "NET-07" "Send redirects disabled" "Envoi redirections ICMP désactivé" "send_redirects=0" ""
else
  add_result "Network" "FAIL" "NET-07" "Send redirects enabled" "Envoi redirections ICMP activé" "send_redirects=$SEND_REDIR" \
    "Add: 'net.ipv4.conf.all.send_redirects=0' to /etc/sysctl.d/"
fi

# NET-08 Martian packet logging
MARTIAN=$(sysctl -n net.ipv4.conf.all.log_martians 2>/dev/null || echo "?")
if [[ "$MARTIAN" == "1" ]]; then
  add_result "Network" "PASS" "NET-08" "Martian packet logging enabled" "Journalisation paquets Martien active" "log_martians=1" ""
else
  add_result "Network" "WARN" "NET-08" "Martian packet logging disabled" "Paquets Martien non journalisés" "log_martians=$MARTIAN" \
    "Enable: 'net.ipv4.conf.all.log_martians=1' in /etc/sysctl.d/"
fi

# NET-09 Reverse path filtering
RP_FILTER=$(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null || echo "?")
if [[ "$RP_FILTER" == "1" || "$RP_FILTER" == "2" ]]; then
  add_result "Network" "PASS" "NET-09" "Reverse path filtering enabled" "Filtrage chemin inverse actif" "rp_filter=$RP_FILTER" ""
else
  add_result "Network" "FAIL" "NET-09" "Reverse path filtering disabled" "Filtrage chemin inverse inactif" "rp_filter=$RP_FILTER" \
    "Enable: 'net.ipv4.conf.all.rp_filter=1' in /etc/sysctl.d/"
fi

# NET-10 IPv6 router advertisements disabled
IPV6_RA=$(sysctl -n net.ipv6.conf.all.accept_ra 2>/dev/null || echo "0")
if [[ "$IPV6_RA" == "0" ]]; then
  add_result "Network" "PASS" "NET-10" "IPv6 RA disabled" "Annonces routeur IPv6 désactivées" "accept_ra=0" ""
else
  add_result "Network" "WARN" "NET-10" "IPv6 RA accepted" "Annonces routeur IPv6 acceptées" "accept_ra=$IPV6_RA" \
    "If IPv6 is not required: 'net.ipv6.conf.all.accept_ra=0' in /etc/sysctl.d/"
fi

# NET-11 ICMP broadcast ignored
BCAST_ICMP=$(sysctl -n net.ipv4.icmp_echo_ignore_broadcasts 2>/dev/null || echo "?")
if [[ "$BCAST_ICMP" == "1" ]]; then
  add_result "Network" "PASS" "NET-11" "ICMP broadcast ignored" "Broadcast ICMP ignoré" "icmp_echo_ignore_broadcasts=1" ""
else
  add_result "Network" "WARN" "NET-11" "ICMP broadcast not ignored" "Broadcast ICMP non ignoré" "icmp_echo_ignore_broadcasts=$BCAST_ICMP" \
    "Enable: 'net.ipv4.icmp_echo_ignore_broadcasts=1' in /etc/sysctl.d/"
fi

# NET-13 IPv6 fully disabled (CIS 3.3.1)
IPV6_ALL=$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo "0")
IPV6_DEF=$(sysctl -n net.ipv6.conf.default.disable_ipv6 2>/dev/null || echo "0")
if [[ "$IPV6_ALL" == "1" && "$IPV6_DEF" == "1" ]]; then
  add_result "Network" "PASS" "NET-13" "IPv6 fully disabled" "IPv6 entièrement désactivé" "disable_ipv6=1 (all + default)" ""
else
  add_result "Network" "WARN" "NET-13" "IPv6 not disabled" "IPv6 non désactivé" "all=$IPV6_ALL default=$IPV6_DEF" \
    "Add to /etc/sysctl.d/99-cis-ipv6.conf: net.ipv6.conf.all.disable_ipv6=1 and net.ipv6.conf.default.disable_ipv6=1"
fi

# NET-12 Wireless interfaces disabled (CIS 3.1.2)
_WIRELESS_OK=false
# Check rfkill (Ubuntu/Debian)
if command -v rfkill &>/dev/null 2>&1; then
  _RF_OUT=$(rfkill list wifi 2>/dev/null || echo "")
  if [[ -z "$_RF_OUT" || "$_RF_OUT" == *"Soft blocked: yes"* || "$_RF_OUT" == *"Hard blocked: yes"* ]]; then
    _WIRELESS_OK=true
  fi
fi
# Check nmcli (RHEL/NetworkManager)
if command -v nmcli &>/dev/null 2>&1; then
  _NM_OUT=$(nmcli radio all 2>/dev/null || echo "")
  [[ "$_NM_OUT" == *"disabled"* ]] && _WIRELESS_OK=true
fi
# Check kernel module blacklist (defense-in-depth fallback)
if grep -rqsE "blacklist\s+(iwlwifi|cfg80211|mac80211)" /etc/modprobe.d/ 2>/dev/null; then
  _WIRELESS_OK=true
fi
if $_WIRELESS_OK; then
  add_result "Network" "PASS" "NET-12" "Wireless interfaces disabled" "Interfaces sans-fil désactivées" "rfkill/nmcli/modprobe blacklist confirmed" ""
else
  add_result "Network" "WARN" "NET-12" "Wireless not disabled" "Interfaces sans-fil actives" "No rfkill block, nmcli disable, or module blacklist found" \
    "Disable: 'rfkill block wifi' (Ubuntu) or 'nmcli radio all off' (RHEL), plus blacklist iwlwifi in /etc/modprobe.d/"
fi
}
