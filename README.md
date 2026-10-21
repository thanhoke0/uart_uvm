# UART TX Verification with UVM 1.2

Dự án học và thực hành Design Verification: thiết kế bộ truyền UART và kiểm chứng bằng SystemVerilog/UVM. Phạm vi hiện tại là **UART TX**, chưa có bộ thu RX, FIFO hay giao tiếp APB.

## Chức năng

- Khung truyền: start = 0 → 8 bit dữ liệu, LSB trước → parity tùy chọn → 1 hoặc 2 stop bit = 1.
- Parity: `0 = none`, `1 = even`, `2 = odd`; giá trị `3` được xử lý như none.
- Baud cấu hình bằng `clks_per_bit` 16 bit; giá trị 0/1 được kẹp về 2.
- Nhận dữ liệu khi `valid && ready` tại cạnh lên. Cấu hình và dữ liệu được chốt cùng lúc.
- Yêu cầu trong lúc `busy` bị bỏ qua. Không có hàng đợi nội bộ.
- Reset bất đồng bộ mức thấp; reset giữa khung hủy khung và trả TX về 1.
- `done` lên 1 trong một chu kỳ sau khi truyền xong toàn bộ stop bit.

## Kết quả đã kiểm tra

- **RTL simulation: PASS, 4.711 khung hoàn chỉnh**, bằng Icarus Verilog 12.0.
- Kiểm tra serial từng chu kỳ, thời gian khung, parity, stop bit, thay đổi cấu hình khi bận, gửi khi bận, reset và phục hồi.
- Mã UVM được kiểm tra cú pháp và elaboration bằng slang 12.0 với thư viện Accellera UVM 1.2: **0 lỗi**. Hai cảnh báo nằm trong mã thư viện UVM.
- **Chưa chạy mô phỏng UVM trên Questa/VCS trong môi trường tạo dự án.** Chưa có kết quả coverage đo thực tế. Script Questa/VCS cần được chạy trên máy có simulator phù hợp.

## Cấu trúc

```text
rtl/uart_tx.sv         UART TX tổng hợp được
tb/uart_if.sv         Interface kết nối DUT/testbench
tb/uart_pkg.sv        Transaction, sequence, sequencer, driver, monitor,
                      agent, scoreboard, coverage, environment, test
tb/tb_top.sv          Clock, DUT, UVM config và watchdog
tests/tb_smoke.sv     Kiểm tra RTL độc lập, chạy bằng Icarus
sim/files.f           Thứ tự compile
sim/run_questa.do     Chạy UVM + lưu UCDB và báo cáo coverage
sim/run_vcs.sh        Chạy UVM với VCS
docs/VPLAN.md         Verification plan và test case plan
docs/LEARNING.md      Thứ tự đọc và thực hành
docs/VALIDATION.md    Chi tiết kiểm tra và giới hạn
```

## Chạy nhanh trên OSIC / Linux

Cần `iverilog`, `vvp`, `make`; để xem waveform cần GTKWave.

```bash
make smoke
make waves
gtkwave build/smoke.vcd
```

Kết quả mong đợi:

```text
PASS: 4711 complete frames; all bytes/formats, busy rejection, config latch, reset recovery
```

**Icarus chạy bài kiểm tra RTL độc lập; không chạy testbench UVM/covergroup của dự án này.**

## Chạy UVM trên Questa

Cần Questa có hỗ trợ class, constrained random và covergroup. ModelSim Intel FPGA bản giới hạn có thể không đủ tính năng này.

Tải mã UVM 1.2 chính thức nếu chưa có:

```bash
git clone --branch UVM_1_2_RELEASE --depth 1 https://github.com/accellera/uvm.git uvm-reference
export UVM_HOME="$PWD/uvm-reference/distrib"
cd sim
vsim -c -do run_questa.do
```

Trong Windows, đặt biến môi trường `UVM_HOME` đến thư mục chứa `src/uvm_pkg.sv`, rồi mở Questa và chạy `do run_questa.do` từ thư mục `sim`.

Đọc kết quả `UVM_ERROR : 0`, `UVM_FATAL : 0`, `Checked 4708 serial frames`, báo cáo coverage và các lỗi simulator. File sinh ra: `uart.ucdb`, `coverage.txt`, `uart.vcd`. Giữ `work` sạch nếu trước đó biên dịch một phiên bản UVM khác.

## Chạy UVM trên VCS

```bash
bash sim/run_vcs.sh +ntb_random_seed=42
```

VCS cần cài sẵn UVM 1.2 qua `-ntb_opts uvm-1.2`. Script này chạy functional coverage trong testbench và in phần trăm; chưa cấu hình xuất báo cáo URG.

## Kiến trúc verification

Sequence tạo yêu cầu → sequencer cấp giao dịch → driver điều khiển input.
Monitor quan sát handshake thật để tạo giao dịch mong đợi, đồng thời lấy mẫu TX ở giữa mỗi bit để giải mã giao dịch thực tế. Hai luồng đi vào scoreboard qua analysis FIFO. Scoreboard tự tính parity và so sánh dữ liệu, start/stop/parity; coverage lấy mẫu khung đã quan sát.

Sequence quét `256 × 3 parity × 2 stop × 3 divisor = 4608` khung, rồi thêm 100 khung ngẫu nhiên. `+N_RANDOM=N` thay đổi phần ngẫu nhiên khi chạy simulation trực tiếp. Đây là constrained-random kết hợp directed exhaustive, không chỉ loopback dữ liệu.

## Coverage

Covergroup gồm 256 bins payload, 3 bins parity, 2 bins stop, 3 bins divisor, framing hợp lệ; có cross payload/parity/stop và parity/stop/divisor. Mục tiêu là 100% các bins hợp lệ này sau quét directed. **Mục tiêu này không phải kết quả đã đo, và không đại diện cho mọi hành vi UART.** Reset giữa khung, busy rejection và divisor clamp được kiểm tra trong bài RTL; chưa có bins UVM tương ứng.

## Công thức

`baud = f_clk / clks_per_bit`.

Ví dụ `f_clk = 50 MHz`, divisor `434` cho baud xấp xỉ `115207 bit/s`. Các divisor 2/8/16 trong UVM dùng để rút ngắn mô phỏng. Khung 8N1 có 10 bit; khung 8E2/8O2 có 12 bit. Thời gian khung bằng `số bit × divisor × T_clk`.

Không có file gán chân hay constraint board: đây là project RTL và verification, cần tích hợp riêng khi đưa lên DE2/DE10.
