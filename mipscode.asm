.data
    filename:   .asciiz "input_matrix.txt"    
     outputfilename: .asciiz "output_matrix.txt"  # Đường dẫn tới file output
    buffer:     .space 4096 
    errormsg: .asciiz "Error: Padded image size must be greater than or equal to kernel size\n"
    temp_buffer:     .space 4096     
        output_size_error: .asciiz "Output size must be greater than 0"  
       n_range_msg: .asciiz "N must be in range [3,7]"
    m_range_msg: .asciiz "M must be in range [2,4]"
    p_range_msg: .asciiz "p must be in range [0,4]"
    s_range_msg: .asciiz "s must be in range [1,3]"   
    newline:    .asciiz "\n"
    space:      .asciiz " "
    decimal_point: .asciiz "."
    # Messages
    msgimage:  .asciiz "\nImage matrix:\n"
    msgkernel: .asciiz "\nKernel matrix:\n"
    msgoutput: .asciiz "\nOutput matrix:\n"
    # Arrays for matrices
    image:      .float 0:2500  
    kernel:     .float 0:2500  
    output:     .float 0:2500    
    padded:     .float 0:10000   
    
    N:          .word 0        # Image matrix size
    M:          .word 0        # Kernel matrix size
    p:          .word 0        # Padding
    s:          .word 0        # Stride
    output_size:.word 0        # Size of output matrix

.text
.globl main
.globl readint
.globl read_float_matrix
.globl display_matrix
.globl convolution

main:
    # Save return address
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    # Open file
    li   $v0, 13
    la   $a0, filename
    li   $a1, 0
    li   $a2, 0
    syscall
    move $s0, $v0            
    # Read file into buffer
    li   $v0, 14
    move $a0, $s0
    la   $a1, buffer
    li   $a2, 1024
    syscall
    # Close file
    li   $v0, 16
    move $a0, $s0
    syscall
    # Process first line for N, M, p, s
    la   $s1, buffer         
    jal  readint            # Read N
        # Check N range (3 <= N <= 7)
    blt  $v0, 3, invalidn
    bgt  $v0, 7, invalidn
    sw   $v0, N
    jal  readint            # Read M 
        # Check M range (2 <= M <= 4) 
    blt  $v0, 2, invalidm
    bgt  $v0, 4, invalidm
    sw   $v0, M
    jal  readint            # Read p
        # Check p range (0 <= p <= 4)
    blt  $v0, 0, invalidp
    bgt  $v0, 4, invalidp
    sw   $v0, p
    jal  readint            # Read s
        # Check s range (1 <= s <= 3)
    blt  $v0, 1, invalids
    bgt  $v0, 3, invalids
    sw   $v0, s
    
    # Calculate output size
    lw   $t0, N
    lw   $t1, M
    lw   $t2, p
    lw   $t3, s
    
    add  $t4, $t0, $t2       # N + p
    add  $t4, $t4, $t2       # N + 2p
    sub  $t9, $t4, $t1       # (N + 2p) - M
    div  $t9, $t3            # ((N + 2p) - M) / s
    mflo $t9
    addi $t9, $t9, 1         # ((N + 2p - M) / s) + 1
    sw   $t9, output_size    # Save output size
    
    # Read and display image matrix
    la   $a0, msgimage
    li   $v0, 4
    syscall
    
    lw   $s2, N              
    mul  $s3, $s2, $s2       
    la   $s4, image          
    li   $s5, 0              
    li   $s6, 0              
    jal  read_float_matrix
    
    # Read and display kernel matrix
    la   $a0, msgkernel
    li   $v0, 4
    syscall
    
    lw   $s2, M              
    mul  $s3, $s2, $s2       
    la   $s4, kernel         
    li   $s5, 0              
    li   $s6, 0              
    jal  read_float_matrix
    
    # Process image with kernel
    jal  convolution
    
    # Display output matrix
    la   $a0, msgoutput
    li   $v0, 4
    syscall
    lw   $s2, output_size    # Load output size
    mul  $s3, $s2, $s2       # Calculate total elements
    la   $s4, output         
    li   $s5, 0              
    li   $s6, 0              
    jal  display_matrix
    # Restore return address and exit
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    
    li   $v0, 10             
    syscall
    # Function to read integer from buffer
readint:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    
    li   $v0, 0              
read_int_loop:
    lb   $t0, ($s1)          # Đọc ký tự
    beq  $t0, 32, read_int_done  # Kết thúc nếu gặp dấu cách
    beq  $t0, 10, read_int_done  # Kết thúc nếu gặp xuống dòng
    beq  $t0, 46, skip_decimal   # Nếu gặp dấu chấm (.), bỏ qua phần thập phân
    sub  $t0, $t0, 48        # Chuyển ASCII sang số
    mul  $v0, $v0, 10        # Nhân kết quả với 10
    add  $v0, $v0, $t0       # Cộng chữ số mới
    addi $s1, $s1, 1         # Tăng con trỏ buffer
    j    read_int_loop

skip_decimal:                 # Hàm mới để bỏ qua phần thập phân
    addi $s1, $s1, 1         # Bỏ qua dấu chấm
skip_decimal_loop:
    lb   $t0, ($s1)          # Đọc ký tự tiếp theo
    beq  $t0, 32, read_int_done  # Nếu gặp dấu cách, kết thúc
    beq  $t0, 10, read_int_done  # Nếu gặp xuống dòng, kết thúc
    beq  $t0, 0, read_int_done   # Nếu gặp null, kết thúc
    addi $s1, $s1, 1         # Tăng con trỏ buffer
    j    skip_decimal_loop

read_int_done:
    addi $s1, $s1, 1         # Bỏ qua ký tự kết thúc
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

# Function to read float matrix
read_float_matrix:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    
    beq  $s5, $s2, read_matrix_done  
    
read_float_loop:
skip_whitespace:
    lb   $t0, ($s1)          
    beq  $t0, 32, skip_next  
    beq  $t0, 10, skip_next  
    beq  $t0, 0, read_matrix_done  
    j    read_number
skip_next:
    addi $s1, $s1, 1         
    j    skip_whitespace

read_number:
    li   $t1, 0              # Integer part
    li   $t2, 0              # Decimal part
    li   $t3, 0              # Decimal count
    li   $t4, 0              # Sign flag
    
    lb   $t0, ($s1)
    bne  $t0, 45, read_int_part  
    li   $t4, 1              
    addi $s1, $s1, 1         
    
read_int_part:
    lb   $t0, ($s1)          
    beq  $t0, 46, read_decimal_part  
    beq  $t0, 32, convert_to_float   
    beq  $t0, 10, convert_to_float   
    beq  $t0, 0, convert_to_float    
    
    sub  $t0, $t0, 48        
    mul  $t1, $t1, 10        
    add  $t1, $t1, $t0       
    addi $s1, $s1, 1         
    j    read_int_part
    
read_decimal_part:
    addi $s1, $s1, 1         
decimal_loop:
    lb   $t0, ($s1)
    beq  $t0, 32, convert_to_float   
    beq  $t0, 10, convert_to_float   
    beq  $t0, 0, convert_to_float    
    
    sub  $t0, $t0, 48        
    mul  $t2, $t2, 10        
    add  $t2, $t2, $t0       
    addi $t3, $t3, 1         
    addi $s1, $s1, 1         
    j    decimal_loop
    
convert_to_float:
    mtc1 $t1, $f1            
    cvt.s.w $f1, $f1         
    
    beqz $t3, check_sign     
    
    mtc1 $t2, $f2            
    cvt.s.w $f2, $f2         
    
    li   $t0, 1              
    move $t5, $t3            
power_loop:
    beqz $t5, apply_decimal
    mul  $t0, $t0, 10        
    addi $t5, $t5, -1
    j    power_loop
    
apply_decimal:
    mtc1 $t0, $f3
    cvt.s.w $f3, $f3         
    div.s $f2, $f2, $f3      
    add.s $f1, $f1, $f2      

check_sign:
    beqz $t4, store_float_result   
    neg.s $f1, $f1           

store_float_result:
    s.s  $f1, ($s4)          
    
    mov.s $f12, $f1          
    li   $v0, 2              
    syscall
    
    la   $a0, space          
    li   $v0, 4
    syscall
    
    addi $s6, $s6, 1         
    addi $s4, $s4, 4         
    
    beq  $s6, $s2, end_row   
    j    read_float_loop     

end_row:
    la   $a0, newline        
    li   $v0, 4
    syscall
    
    li   $s6, 0              
    addi $s5, $s5, 1         
    bne  $s5, $s2, read_float_loop  
    
read_matrix_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

# Function to display matrix
# Function to display matrix with 4 decimal places
display_matrix:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    
    beq  $s5, $s2, display_done
    
display_loop:
    l.s  $f12, ($s4)         # Load float value
    
    # Print integer part
    trunc.w.s $f0, $f12      # Truncate to integer
    mfc1 $a0, $f0            # Move to integer register
    li   $v0, 1              # Print integer
    syscall
    
    # Print decimal point
    li   $v0, 4              
    la   $a0, decimal_point
    syscall
    
    # Get decimal part
    cvt.w.s $f0, $f12        # Convert to integer
    mfc1 $t0, $f0            # Get integer part
    mtc1 $t0, $f0
    cvt.s.w $f0, $f0         # Convert back to float
    sub.s $f12, $f12, $f0    # Get decimal part
    
    # Multiply by 10000 to get 4 decimal places
    li   $t0, 10000
    mtc1 $t0, $f1
    cvt.s.w $f1, $f1
    mul.s $f12, $f12, $f1
    
    # Convert to absolute value if negative
    abs.s $f12, $f12
    
    # Convert to integer
    cvt.w.s $f0, $f12
    mfc1 $t0, $f0            # Get decimal digits
    
    # Print leading zeros if needed
    li   $t1, 1000
    div  $t0, $t1
    mflo $t2                 # First digit
    beq  $t2, $zero, print_zero1
    j    continue1
print_zero1:
    li   $v0, 11
    li   $a0, 48            # Print '0'
    syscall
    
continue1:
    li   $t1, 100
    div  $t0, $t1
    mflo $t2                 # First two digits
    beq  $t2, $zero, print_zero2
    j    continue2
print_zero2:
    li   $v0, 11
    li   $a0, 48            # Print '0'
    syscall
    
continue2:
    li   $t1, 10
    div  $t0, $t1
    mflo $t2                 # First three digits
    beq  $t2, $zero, print_zero3
    j    continue3
print_zero3:
    li   $v0, 11
    li   $a0, 48            # Print '0'
    syscall
    
continue3:
    beq  $t0, $zero, print_zero4
    j    print_decimal
print_zero4:
    li   $v0, 11
    li   $a0, 48            # Print '0'
    syscall
    j    print_space
    
print_decimal:
    # Print decimal digits
    move $a0, $t0
    li   $v0, 1
    syscall
    
print_space:
    la   $a0, space          
    li   $v0, 4
    syscall
    
    addi $s6, $s6, 1         
    addi $s4, $s4, 4         
    
    beq  $s6, $s2, display_end_row
    j    display_loop
    
display_end_row:
    la   $a0, newline        
    li   $v0, 4
    syscall
    li   $s6, 0              
    addi $s5, $s5, 1         
    bne  $s5, $s2, display_loop
    
display_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
    # Function to perform 2D convolution
convolution:
    # Save registers
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
    
    # Load parameters
    lw   $t0, N              # Original image size
    lw   $t1, M              # Kernel size
    lw   $t2, p              # Padding size
    lw   $t3, s              # Stride
    
    # Calculate padded size
    add  $t4, $t0, $t2       
    add  $t4, $t4, $t2       # padded_size = N + 2p
        blt  $t4, $t1, error_size    # If padded_size < kernel_size, jump to error
    # Initialize padded matrix with zeros
    mul  $t8, $t4, $t4       # Total elements in padded matrix
    la   $s0, padded         # Load padded matrix address
    mtc1 $zero, $f0
    cvt.s.w $f0, $f0         # Convert 0 to float
    
initpadded:
    beqz $t8, copytopadded
    s.s  $f0, ($s0)          # Store zero
    addi $s0, $s0, 4         # Next element
    addi $t8, $t8, -1        # Decrement counter
    j    initpadded
    
copytopadded:
    # Copy original image to padded matrix
    li   $t5, 0              # Row counter
copyrow:
    beq  $t5, $t0, startconvolution
    li   $t6, 0              # Column counter
    
copycol:
    beq  $t6, $t0, copynextrow
    
    # Calculate source index
    mul  $t8, $t5, $t0
    add  $t8, $t8, $t6
    sll  $t8, $t8, 2
    la   $s0, image
    add  $s0, $s0, $t8
    l.s  $f0, ($s0)          # Load value from image
    
    # Calculate destination index
    add  $t7, $t5, $t2       # Row + padding
    mul  $t8, $t7, $t4       # (Row + p) * padded_size
    add  $t7, $t6, $t2       # Col + padding
    add  $t8, $t8, $t7       # Final index
    sll  $t8, $t8, 2
    la   $s0, padded
    add  $s0, $s0, $t8
    s.s  $f0, ($s0)          # Store in padded matrix
    
    addi $t6, $t6, 1
    j    copycol
    
copynextrow:
    addi $t5, $t5, 1
    j    copyrow
    
startconvolution:
    # Calculate output size
    sub  $t9, $t4, $t1       # padded_size - kernel_size
    div  $t9, $t3            # (padded_size - kernel_size) / stride
    mflo $t9
    addi $t9, $t9, 1         # output_size = ((N + 2p - M) / s) + 1
        # Thêm kiểm tra output_size
    blez $t9, invalid_output_size    # Nếu output_size <= 0, báo lỗi
    sw   $t9, output_size    # Save output size
    li   $t5, 0              # Output row counter
convrow:
    beq  $t5, $t9, convdone
    li   $t6, 0              # Output column counter
    
convcol:
    beq  $t6, $t9, convnextrow
    
    # Initialize accumulator
    mtc1 $zero, $f0
    cvt.s.w $f0, $f0
    
    li   $s0, 0              # Kernel row counter
kernelrow:
    beq  $s0, $t1, storeconvresult
    li   $s1, 0              # Kernel column counter
    
kernelcol:
    beq  $s1, $t1, kernelnextrow
    
    # Calculate input position
    mul  $s2, $t5, $t3       # output_row * stride
    add  $s2, $s2, $s0       # Add kernel row
    
    mul  $s3, $t6, $t3       # output_col * stride
    add  $s3, $s3, $s1       # Add kernel column
    
    # Get input value
    mul  $t8, $s2, $t4
    add  $t8, $t8, $s3
    sll  $t8, $t8, 2
    la   $k0, padded
    add  $k0, $k0, $t8
    l.s  $f1, ($k0)
    
    # Get kernel value
    mul  $t8, $s0, $t1
    add  $t8, $t8, $s1
    sll  $t8, $t8, 2
    la   $k0, kernel
    add  $k0, $k0, $t8
    l.s  $f2, ($k0)
    
    # Multiply and accumulate
    mul.s $f1, $f1, $f2
    add.s $f0, $f0, $f1
    
    addi $s1, $s1, 1
    j    kernelcol
    
kernelnextrow:
    addi $s0, $s0, 1
    j    kernelrow
    
storeconvresult:
    # Store in output matrix
    mul  $t8, $t5, $t9
    add  $t8, $t8, $t6
    sll  $t8, $t8, 2
    la   $k0, output
    add  $k0, $k0, $t8
    s.s  $f0, ($k0)
    
    addi $t6, $t6, 1
    j    convcol
    
convnextrow:
    addi $t5, $t5, 1
    j    convrow
convdone:
    # Restore registers
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    j   write_output_file
write_output_file:
    addi $sp, $sp, -20
    sw   $ra, 0($sp)
    sw   $s0, 4($sp)
    sw   $s1, 8($sp)
    sw   $s2, 12($sp)
    sw   $s3, 16($sp)
    
    # Open output file
    li   $v0, 13
    la   $a0, outputfilename
    li   $a1, 1        # Write mode
    li   $a2, 0
    syscall
    move $s0, $v0      # Save file descriptor
    
    # Initialize buffer position
    la   $s1, temp_buffer   # Buffer address
    move $s2, $s1          # Current position in buffer
    
    # Get matrix dimensions
    lw   $s3, output_size  # Size of output matrix
    mul  $t0, $s3, $s3     # Total elements
    
    la   $t1, output       # Output matrix address
    li   $t2, 0           # Counter
    
write_loop:
    beq  $t2, $t0, write_to_file
    
    # Load float
    l.s  $f12, ($t1)
    
    # Convert float to string in temp_buffer
    # Integer part
    trunc.w.s $f0, $f12
    mfc1 $t3, $f0
    
    # Handle negative numbers
    li   $t4, 0           # Sign flag
    bgez $t3, print_int_part
    li   $t4, 1
    neg  $t3, $t3
    
    # Print minus sign if negative
    beqz $t4, print_int_part
    li   $t5, 45          # '-' character
    sb   $t5, ($s2)
    addi $s2, $s2, 1
    
print_int_part:
    # Convert integer to string
    move $t5, $t3
    li   $t6, 10
    li   $t7, 0           # Digit count
    
    # Push digits onto stack
digit_to_stack:
    div  $t5, $t6
    mfhi $t8              # Remainder
    addi $t8, $t8, 48     # Convert to ASCII
    addi $sp, $sp, -4
    sw   $t8, 0($sp)
    addi $t7, $t7, 1
    mflo $t5
    bnez $t5, digit_to_stack
    
    # Pop digits from stack
pop_digits:
    beqz $t7, print_decimal1
    lw   $t8, 0($sp)
    addi $sp, $sp, 4
    sb   $t8, ($s2)
    addi $s2, $s2, 1
    addi $t7, $t7, -1
    j    pop_digits
    
print_decimal1:
    # Print decimal point
    li   $t5, 46          # '.' character
    sb   $t5, ($s2)
    addi $s2, $s2, 1
    
    # Get decimal part
    cvt.w.s $f0, $f12
    mfc1 $t3, $f0
    mtc1 $t3, $f0
    cvt.s.w $f0, $f0
    sub.s $f12, $f12, $f0
    
    # Multiply by 10000 for 4 decimal places
    li   $t3, 10000
    mtc1 $t3, $f1
    cvt.s.w $f1, $f1
    mul.s $f12, $f12, $f1
    abs.s $f12, $f12
    cvt.w.s $f0, $f12
    mfc1 $t3, $f0
    
    # Convert decimal to string with leading zeros
    li   $t5, 1000
    li   $t6, 4           # Number of decimal places
decimal_to_string:
    div  $t3, $t5
    mflo $t7              # Quotient
    mfhi $t3              # Remainder
    addi $t7, $t7, 48     # Convert to ASCII
    sb   $t7, ($s2)
    addi $s2, $s2, 1
    div  $t5, $t5, 10
    addi $t6, $t6, -1
    bnez $t6, decimal_to_string
    
    # Add space after number
    li   $t5, 32          # Space character
    sb   $t5, ($s2)
    addi $s2, $s2, 1
    addi $t1, $t1, 4      # Next float
    addi $t2, $t2, 1
    j    write_loop
write_to_file:
    # Calculate buffer length
    sub  $t0, $s2, $s1
    
    # Write to file
    li   $v0, 15
    move $a0, $s0
    la   $a1, temp_buffer
    move $a2, $t0
    syscall
    
    # Close file
    li   $v0, 16
    move $a0, $s0
    syscall
    
    # Restore registers
    lw   $ra, 0($sp)
    lw   $s0, 4($sp)
    lw   $s1, 8($sp)
    lw   $s2, 12($sp)
    lw   $s3, 16($sp)
    addi $sp, $sp, 20
    
    jr   $ra
    .text
        error_size:
    # Print error message
    li   $v0, 4
    la   $a0, errormsg
    syscall
        li   $v0, 10            # Exit program
    syscall
    invalidn:
    li   $v0, 4
    la   $a0, n_range_msg
    syscall
    li   $v0, 10            # Exit program
    syscall

invalidm:
    li   $v0, 4
    la   $a0, m_range_msg
    syscall
    li   $v0, 10            # Exit program
    syscall

invalidp:
    li   $v0, 4
    la   $a0, p_range_msg
    syscall
    li   $v0, 10            # Exit program
    syscall
    invalid_output_size:
    li   $v0, 4
    la   $a0, output_size_error
    syscall
    li   $v0, 10            # Exit program
    syscall
invalids:
    li   $v0, 4
    la   $a0, s_range_msg
    syscall
    li   $v0, 10            # Exit program
    syscall
    li   $v0, 10            # Exit program
    syscall
    
