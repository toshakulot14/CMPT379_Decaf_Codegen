
declare void @print_int(i32)
declare void @print_string(i8*)
declare i32 @read_int()

; store the newline as a string constant
; more specifically as a constant array containing i8 integers
@.nl = constant [2 x i8] c"\0A\00"


define i32 @add2(i32 %a, i32 %b) {
entry:
  
  %aa = alloca i32
  %bb = alloca i32

  store i32 %a , i32* %aa
  store i32 %b , i32* %bb
  
  %tmp1 = icmp eq i32 %a, 0
  br i1 %tmp1, label %done, label %recurse

recurse:
; insert LLVM assembly here
  %a_tmp = load i32* %aa
  %b_tmp = load i32* %bb

  %tmp2 = sub i32 %a_tmp , 1
  %tmp3 = add i32 1 , %b_tmp

  store i32 %tmp2 , i32* %aa
  store i32 %tmp3 , i32* %bb
  
  ;call void @print_int(i32 %tmp3)
  ;br label %entry
 
  %tmp4 = icmp eq i32 %tmp2, 0
  br i1 %tmp4, label %done, label %recurse

done:
; insert LLVM assembly here
  %resultz = load i32* %bb
  ret i32 %resultz
}

define i32 @main() {
entry:
  %tmp5 = call i32 @add2(i32 3, i32 4)
  call void @print_int(i32 %tmp5)
  ; convert the constant newline array into a pointer to i8 values
  ; using getelementptr, arg1 = @.nl, 
  ; arg2 = first element stored in @.nl which is of type [2 x i8]
  ; arg3 = the first element of the constant array
  ; getelementptr will return the pointer to the first element
  %cast.nl = getelementptr [2 x i8]* @.nl, i8 0, i8 0
  call void @print_string(i8* %cast.nl)
  ret i32 0
}

