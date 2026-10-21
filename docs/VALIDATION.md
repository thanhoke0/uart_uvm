# Kết quả kiểm tra – 21/10/2026

## RTL simulation

Icarus Verilog 12.0, compile `-g2012 -Wall -s tb_smoke` và chạy vvp:

```text
PASS: 4711 complete frames; all bytes/formats, busy rejection, config latch, reset recovery
```

Số khung: 4608 directed + 100 random + 2 divisor clamp/reserved mode + 1 recovery. Một khung reset giữa chừng không tính là khung hoàn chỉnh. Bài kiểm tra so TX mỗi chu kỳ và kiểm tra thời điểm done; không chỉ so payload ở cuối.

## UVM static compile/elaboration

slang 12.0 với Accellera UVM 1.2, tag `UVM_1_2_RELEASE`, commit `71f30a7473118b3cea582d7673c3af8e161fce71`, `UVM_NO_DPI`, top `tb_top`:

```text
Build succeeded: 0 errors, 2 warnings
```

Hai cảnh báo empty-body nằm trong uvm_resource.svh và uvm_sequencer.svh của thư viện. Static elaboration kiểm tra cấu trúc/cú pháp/kiểu, không thực thi scheduler UVM hay randomization và không chứng minh testbench chạy đúng trên mọi simulator.

## Kiểm tra khả năng bắt lỗi

Đảo bit parity trong một bản sao RTL rồi chạy lại cùng testbench: simulation thất bại tại khung even parity đầu tiên (data=00, cycle=18, TX=1 trong khi mong đợi 0). Bản lỗi chỉ dùng kiểm tra testbench và không nằm trong project bàn giao.

## Chưa thực hiện

- Chưa chạy UVM simulation trên Questa/VCS.
- Chưa có UCDB hoặc phần trăm functional/code coverage đo thực tế.
- Các script vendor được cung cấp để chạy tiếp; chưa được xác minh với license/cài đặt vendor cụ thể.
- GitHub Actions chỉ chạy RTL smoke; không chạy UVM thương mại.
