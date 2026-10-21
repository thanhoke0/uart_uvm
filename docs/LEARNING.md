# Học dự án theo từng bước

1. Đọc README và vẽ khung 8N1 của 0xA5: start 0, data 1-0-1-0-0-1-0-1, stop 1.
2. Đọc rtl/uart_tx.sv. Theo dõi frame, index, count, divisor; xác định cạnh chốt valid && ready.
3. Chạy make smoke. Chỉ sau khi PASS mới xem waveform bằng make waves và GTKWave.
4. Trong GTKWave thêm clk, rst_n, valid, ready, data, parity_mode, clks_per_bit, tx, busy, done. Phóng to khung đầu. Đo một bit bằng divisor chu kỳ clock.
5. Đọc uart_item và uart_sequence: phân biệt transaction và tín hiệu. Giải thích vì sao 4608 khung quét hết mọi tổ hợp đã chọn.
6. Đọc uart_driver: input đổi ở cạnh xuống, DUT nhận ở cạnh lên, driver đợi done rồi mới hoàn tất item.
7. Đọc uart_monitor: expected lấy từ handshake; actual giải mã TX ở tâm bit. Tránh dùng data input làm dữ liệu actual vì sẽ che lỗi DUT.
8. Đọc scoreboard: hai analysis FIFO ghép giao dịch theo thứ tự, reference parity tính độc lập từ dữ liệu mong đợi.
9. Đọc coverage: bins đo tình huống đã xảy ra; scoreboard quyết định dữ liệu đúng hay sai. Phủ đủ bins không thay thế việc kiểm tra đúng/sai.
10. Đọc agent/env/test để hiểu build_phase, connect_phase, run_phase và objection. Chạy Questa/VCS ở máy có license và xem kết quả thật.

## Bài tập sửa lỗi có chủ đích

Tạo bản sao RTL rồi đảo công thức parity, đổi TX idle thành 0, hoặc truyền MSB trước. Chạy lại make smoke và UVM: kết quả phải báo lỗi. Sau đó khôi phục RTL. Đây là cách kiểm tra testbench có bắt được lỗi thay vì chỉ tạo ra waveform.

## Chuẩn bị trình bày

Giải thích được: tại sao có driver lẫn monitor; parity even/odd khác nhau thế nào; tại sao config phải chốt; tại sao không chạy UVM này bằng Icarus; reset giữa khung làm scoreboard cần cơ chế flush thế nào; các điểm nào còn chưa được kiểm chứng.
