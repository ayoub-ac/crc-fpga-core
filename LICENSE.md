# License

This IP core is dual-licensed.

## GPL-3.0-or-later (open-source use)

Copyright (C) 2026 Ayoub Achour

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see <https://www.gnu.org/licenses/>.

The full GPL-3.0 text is canonical and lives at the FSF link above. A copy is available for convenience: <https://www.gnu.org/licenses/gpl-3.0.txt>.

**What this means in practice**: if you use this RTL in a project, the project itself (including any FPGA bitstream produced from it) must also be released under GPL-3.0-or-later. The GPL is "viral" — your downstream users must receive the same rights you received, including the right to the complete corresponding source.

If that is fine for your project, you are good to go. No fee, no email needed.

## Commercial license (closed-source / proprietary use)

If you want to use this core in a product whose source is not GPL — for example a closed-source network MAC, an industrial Modbus gateway, a CAN-FD controller, an NVMe accelerator, an automotive safety controller, or any FPGA-based product whose bitstream you do not want to be forced to publish — you need a commercial license.

The commercial license:

- removes the GPL viral requirement,
- grants you (and your company) the right to integrate the core into closed-source products,
- gives you a clear, written grant you can show to your customers and to a due-diligence auditor,
- includes a 1-year fix window on bugs and clarifications.

To obtain a commercial license, open an issue at <https://github.com/ayoub-ac/crc-fpga-core/issues> with the title "Commercial license enquiry" or contact the author through the email listed on the GitHub profile.

## FAQ

**Q. I just want to evaluate the core in a prototype. Do I need a commercial license?**

A. No. Pure evaluation, research, and academic use is covered by the GPL. The commercial license matters only when you ship the resulting bitstream as part of a non-GPL product to a third party.

**Q. My company already has a GPL compliance program. Can we just use the GPL terms?**

A. Yes, as long as the resulting product (bitstream and the wider design) is itself GPL-3.0-or-later compliant.

**Q. Does the commercial license cover my whole product, or just this core?**

A. Just this core (and any modifications you make to it). The rest of your product is yours and stays yours.

**Q. Are bug fixes and clarifications included in the commercial license?**

A. Yes, for one year from the date of purchase. Major-version upgrades are negotiated separately.
