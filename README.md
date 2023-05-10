# bulk add external ids as SSO identifiers
It's a bash script, so it requires Linux installed. In Windows 10, you can install WSL in powershell.
```powershell
wsl --install -d ubuntu
```
## bulk-add-eids.sh

A tool to bulk add external ids as SSO identifiers leveraging script **./add-external-id.sh** and **bc**

Usage:
```bash
./bulk-add-eids.sh [-d] [-f] [-p gc_profile] [-a authority] <input_file>
```
## add-external-id.sh
A tool to add external id instead of email for SSO
leveraging Genesys Cloud CLI (**gc**) and JSon processor (**jq**)

Usage:
```bash
./add-external-id.sh [-d] [-p gc_profile] [-a authority] <user_id> <external_id>
```
## input CSV file
The CSV file should includes only 2 columns: email and external_id.

The following command can be used to convert Windows newline(CRLF) to Unix newline(LF) and trim spaces
```bash
sed -r 's/\r//g;s/^\s*//g;s/\s*,\s*/,/g;s/\s*$//g'
```
