
declare void @print_int(i32)
declare void @print_string(i8*)
declare i32 @read_int()

; store the newline as a string constant
; more specifically as a constant array containing i8 integers
@.nl = constant [2 x i8] c"\0A\00"


define i32 @factorial(i32 %X) nounwind uwtable readnone {
  %1 = icmp eq i32 %X, 0
  br i1 %1, label %tailrecurse._crit_edge, label %tailrecurse

tailrecurse:                                      ; preds = %tailrecurse, %0
  %X.tr2 = phi i32 [ %2, %tailrecurse ], [ %X, %0 ]
  %accumulator.tr1 = phi i32 [ %3, %tailrecurse ], [ 1, %0 ]
  %2 = add nsw i32 %X.tr2, -1
  %3 = mul nsw i32 %X.tr2, %accumulator.tr1
  %4 = icmp eq i32 %2, 0
  br i1 %4, label %tailrecurse._crit_edge, label %tailrecurse

tailrecurse._crit_edge:                           ; preds = %tailrecurse, %0
  %accumulator.tr.lcssa = phi i32 [ 1, %0 ], [ %3, %tailrecurse ]
  ret i32 %accumulator.tr.lcssa
}


define i32 @main() {
entry:
  %tmp5 = call i32 @factorial(i32 3)
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

