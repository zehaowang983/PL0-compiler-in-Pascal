# 编译原理实验

Enviroment:

```bash
Free Pascal Compiler version 3.0.4 [2018/09/30] for x86_64
Copyright (c) 1993-2017 by Florian Klaempfl and others
Target OS: Darwin for x86_64
```

Usage:

`fpc pl0_compiler.pas`

`./pl0_compiler <pl0_src> <output>` 



## PL0语法

```
program = block "." .

block = [ "const" ident "=" number {"," ident "=" number} ";"]
        [ "var" ident {"," ident} ";"]
        { "procedure" ident ";" block ";" } statement .

statement = [ ident ":=" expression | "call" ident 
              | "?" ident | "!" expression 
              | "begin" statement {";" statement } "end" 
              | "if" condition "then" statement 
              | "while" condition "do" statement ].

condition = "odd" expression |
            expression ("="|"#"|"<"|"<="|">"|">=") expression .

expression = [ "+"|"-"] term { ("+"|"-") term}.

term = factor {("*"|"/") factor}.

factor = ident | number | "(" expression ")".
```

**PL/0** is a [programming language](https://en.wikipedia.org/wiki/Programming_language), intended as an [educational programming language](https://en.wikipedia.org/wiki/Educational_programming_language), that is similar to but much simpler than [Pascal](https://en.wikipedia.org/wiki/Pascal_(programming_language)), a [general-purpose programming language](https://en.wikipedia.org/wiki/General-purpose_programming_language). It serves as an example of how to construct a [compiler](https://en.wikipedia.org/wiki/Compiler). 

- 无实型
- 只有if和while流控制语句



## Pascal编译器学习

1. **机器语言** -- 为计算机CPU提供基本指令的实际二进制代码。这些通常是非常简单的命令，例如将两个数相加，或者把数据从内存中的某个位置移动到另外一个位置（寄存器）。
2. **汇编语言** -- 让人类能够直接为计算机编程而不用记忆二进制数字串的一种方法。汇编语言指令和机器代码一一对应。例如，在Intel x86架构的机器上，ADD和MOV分别是加法操作和移动操作的助记符。
3. **高级语言** -- 允许人类在编写复杂程序的时候不用一条指令一条指令地写。高级语言包括Pascal，C，C++，FORTRAN，Java，BASIC以及其它许多语言。高级语言中的一个命令，例如向文件中写入一个字符串，可能会翻译成几十甚至几百条机器语言指令。

微处理器只能够直接运行机器语言程序。汇编语言程序会被翻译成机器语言。同样地，用Pascal等高级语言写的程序也必须被转换为机器语言才能运行。这种转换就是编译。

完成这种转换的的程序就叫做**编译器**。这种程序相当复杂，因为它不仅要根据一行行的代码创建机器语言指令，经常还要优化代码让它运行得更快，添加差错校验码，并且还要将这个代码跟存放在别处的子程序链接起来。**例如，当你叫计算机打印一些东西到屏幕上的时候，编译器把这个命令转换成对一个事先写好的模块的调用。然后你的代码必须被链接到编译器开发商提供的代码才能产生一个可执行程序。**



在高级语言中，有三个基本术语要记住：

1. 源代码 --Pascal源代码文件通常以"`.pas`"或者"`.pp`"作为后缀。
2. 目标代码 -- 编译的结果。目标代码通常程序的一个模块，而且由于它不完整，它还不能运行。在DOS/Windows系统中，这种文件通常的后缀名是"`.obj`"
3. 可执行代码 -- 最终的结果。一个程序起能够运行起来所需要的所有的目标代码模块都被链接到一起。在DOS/Windows系统中，这种文件的后缀通常是"`.exe`"



## 对原PL0编译程序的修改之处

1. 在getsym词法分析程序中增加对">"，"<"，">="，"<="，"<>"的识别

```pascal
    else if ch = '<' {处理'<'}
           then begin	
                   getch;	
                   if ch = '='	
                   then begin
                           sym := leq;	{表示小于等于}
                           getch	{读下一个字符}
                       end
                   else if ch = '>' {处理'>'}
                   then begin
                           sym := neq;	{表示不等于}
                           getch
                       end
                   else sym := lss	{表示小于}
               end
   
           else if ch = '>' {处理'<'}
           then begin	
                   getch;	
                   if ch = '='	
                   then begin
                           sym := geq;	{表示大于等于}
                           getch	{读下一个字符}
                       end
                   else sym := gtr	{表示大于}
               end
```


2. 由于使用go会编译报错，故当读到文件末尾的时候直接关闭文件并结束程序。

   ```
   Goto statements are not allowed between different procedures
   ```

   ```pascal
    if eof(file_in) {如果已到文件尾} 
    then begin 
        write(file_out,'PROGRAM INCOMPLETE'); {报错}
        close(file_in);	
        close(file_out);{关闭文件}
        exit; {退出}
    end; 
   ```

3. input为pl0源文件文件名，output为输出文件名

   - 在主程序增加文件操作
   - 将write和writeln从控制台输出改为写入输出文件中

```pascal
begin  {主程序}
 	assign(file_in,paramstr(1));
    assign(file_out,paramstr(2));	{将文件名字符串变量赋值给文件变量}
    reset(file_in);
    rewrite(file_out);	{打开文件}
	...
	close(file_in);	
    close(file_out);	{关闭文件}
end.
```

```pascal
{增加全局变量定义}
file_in : text;    {源代码文件}      
file_out :  text;  {输出文件}
...


 {读新的一行} 
 ll := 0; 
 cc := 0; 
 write(file_out,cx : 5, ' '); {cx : 5 位数,输出代码地址，宽度为5} 
 while not eoln(file_in) do {如果不是行末} 
 begin 
     ll := ll + 1; {将行缓冲区的长度+1}
     read(file_in,ch);	{从文件中读取一个字符到ch中}
     write(file_out,ch); {控制台输出ch}
     line[ll] := ch {把这个字符放到当前行末尾}
 end; 
 writeln(file_out); {换行}
 readln(file_in);	{源文件读取从下一行开始}
 ll := ll + 1; {将行缓冲区的长度+1}
 line[ll] := ' ' { process end-line }	{行数组最后一个元素为空格}
...
```

第一步结果：

![1](Assets/1.jpg)

PL0源程序：

```pascal
const m = 7, n = 85; 

var x, y, z, q, r; 

procedure multiply; 
    var a, b; 
    begin 
        a := x; 
        b := y; 
        z := 0;
        while b > 0 do 
        begin 
            if odd b then z := z + a; 
                a := 2*a ; b := b/2 ; 
        end
    end;
    
procedure divide; 
    var w; 
    begin r := x; q := 0; w := y; 
    while w <= r do 
        w := 2*w; 
        while w > y do
        begin 
            q := 2*q; 
            w := w/2; 
            if w <= r then 
            begin 
                r := r-w; 
                q := q+1 
            end 
        end
    end;

procedure gcd;
    var f, g ; 
    begin 
        f := x; 
        g := y; 
        while f <> g do 
        begin 
            if f < g then 
                g := g-f; 
            if g < f then 
                f := f-g; 
        end; 
        z := f 
    end;

begin  
    x := m; y := n; call multiply;
    x := 25; y := 3; call divide;
    x := 84; y:= 36; call gcd; 
end.
```

输出结果

```
    0 const m = 7, n = 85; 
    1 
    1 var x, y, z, q, r; 
    1 
    1 procedure multiply; 
    1     var a, b; 
    2     begin 
    3         a := x; 
    5         b := y; 
    7         z := 0;
    9         while b > 0 do 
   13         begin 
   13             if odd b then z := z + a; 
   20                 a := 2*a ; b := b/2 ; 
   28         end
   28     end;
    2  INT    0    5
    3  LOD    1    3
    4  STO    0    3
    5  LOD    1    4
    6  STO    0    4
    7  LIT    0    0
    8  STO    1    5
    9  LOD    0    4
   10  LIT    0    0
   11  OPR    0   12
   12  JPC    0   29
   13  LOD    0    4
   14  OPR    0    6
   15  JPC    0   20
   16  LOD    1    5
   17  LOD    0    3
   18  OPR    0    2
   19  STO    1    5
   20  LIT    0    2
   21  LOD    0    3
   22  OPR    0    4
   23  STO    0    3
   24  LOD    0    4
   25  LIT    0    2
   26  OPR    0    5
   27  STO    0    4
   28  JMP    0    9
   29  OPR    0    0
   30     
   30 procedure divide; 
   30     var w; 
   31     begin r := x; q := 0; w := y; 
   38     while w <= r do 
   42         w := 2*w; 
   47         while w > y do
   51         begin 
   51             q := 2*q; 
   55             w := w/2; 
   59             if w <= r then 
   62             begin 
   63                 r := r-w; 
   67                 q := q+1 
   69             end 
   71         end
   71     end;
   31  INT    0    4
   32  LOD    1    3
   33  STO    1    7
   34  LIT    0    0
   35  STO    1    6
   36  LOD    1    4
   37  STO    0    3
   38  LOD    0    3
   39  LOD    1    7
   40  OPR    0   13
   41  JPC    0   47
   42  LIT    0    2
   43  LOD    0    3
   44  OPR    0    4
   45  STO    0    3
   46  JMP    0   38
   47  LOD    0    3
   48  LOD    1    4
   49  OPR    0   12
   50  JPC    0   72
   51  LIT    0    2
   52  LOD    1    6
   53  OPR    0    4
   54  STO    1    6
   55  LOD    0    3
   56  LIT    0    2
   57  OPR    0    5
   58  STO    0    3
   59  LOD    0    3
   60  LOD    1    7
   61  OPR    0   13
   62  JPC    0   71
   63  LOD    1    7
   64  LOD    0    3
   65  OPR    0    3
   66  STO    1    7
   67  LOD    1    6
   68  LIT    0    1
   69  OPR    0    2
   70  STO    1    6
   71  JMP    0   47
   72  OPR    0    0
   73 
   73 procedure gcd;
   73     var f, g ; 
   74     begin 
   75         f := x; 
   77         g := y; 
   79         while f <> g do 
   83         begin 
   83             if f < g then 
   86                 g := g-f; 
   91             if g < f then 
   94                 f := f-g; 
   99         end; 
  100         z := f 
  101     end;
   74  INT    0    5
   75  LOD    1    3
   76  STO    0    3
   77  LOD    1    4
   78  STO    0    4
   79  LOD    0    3
   80  LOD    0    4
   81  OPR    0    9
   82  JPC    0  100
   83  LOD    0    3
   84  LOD    0    4
   85  OPR    0   10
   86  JPC    0   91
   87  LOD    0    4
   88  LOD    0    3
   89  OPR    0    3
   90  STO    0    4
   91  LOD    0    4
   92  LOD    0    3
   93  OPR    0   10
   94  JPC    0   99
   95  LOD    0    3
   96  LOD    0    4
   97  OPR    0    3
   98  STO    0    3
   99  JMP    0   79
  100  LOD    0    3
  101  STO    1    5
  102  OPR    0    0
  103 
  103 begin  
  104     x := m; y := n; call multiply;
  109     x := 25; y := 3; call divide;
  114     x := 84; y:= 36; call gcd; 
  119 end.
  103  INT    0    8
  104  LIT    0    7
  105  STO    0    3
  106  LIT    0   85
  107  STO    0    4
  108  CAL    0    2
  109  LIT    0   25
  110  STO    0    3
  111  LIT    0    3
  112  STO    0    4
  113  CAL    0   31
  114  LIT    0   84
  115  STO    0    3
  116  LIT    0   36
  117  STO    0    4
  118  CAL    0   74
  119  OPR    0    0
START PL/0
END PL/0
```

