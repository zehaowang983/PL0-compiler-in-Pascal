# 编译原理实验

Usage:

`fpc pl0_compiler.pas`

`./pl0_compiler`

然后输入pl0源文件



## Pascal 编译器学习

1. **机器语言** -- 为计算机CPU提供基本指令的实际二进制代码。这些通常是非常简单的命令，例如将两个数相加，或者把数据从内存中的某个位置移动到另外一个位置（寄存器）。
2. **汇编语言** -- 让人类能够直接为计算机编程而不用记忆二进制数字串的一种方法。汇编语言指令和机器代码一一对应。例如，在Intel x86架构的机器上，ADD和MOV分别是加法操作和移动操作的助记符。
3. **高级语言** -- 允许人类在编写复杂程序的时候不用一条指令一条指令地写。高级语言包括Pascal，C，C++，FORTRAN，Java，BASIC以及其它许多语言。高级语言中的一个命令，例如向文件中写入一个字符串，可能会翻译成几十甚至几百条机器语言指令。

微处理器只能够直接运行机器语言程序。汇编语言程序会被翻译成机器语言。同样地，用Pascal等高级语言写的程序也必须被转换为机器语言才能运行。这种转换就是编译。

完成这种转换的的程序就叫做**编译器**。这种程序相当复杂，因为它不仅要根据一行行的代码创建机器语言指令，经常还要优化代码让它运行得更快，添加差错校验码，并且还要将这个代码跟存放在别处的子程序链接起来。**例如，当你叫计算机打印一些东西到屏幕上的时候，编译器把这个命令转换成对一个事先写好的模块的调用。然后你的代码必须被链接到编译器开发商提供的代码才能产生一个可执行程序。**



在高级语言中，有三个基本术语要记住：

1. 源代码 -- 就是你写的代码。它有一个典型的扩展名来表示所用的语言。例如，Pascal源代码文件通常以"`.pas`"作为后缀，而C++代码文件的后缀通常是"`.cpp`"
2. 目标代码 -- 编译的结果。目标代码通常程序的一个模块，而且由于它不完整，它还不能运行。在DOS/Windows系统中，这种文件通常的后缀名是"`.obj`"
3. 可执行代码 -- 最终的结果。一个程序起能够运行起来所需要的所有的目标代码模块都被链接到一起。在DOS/Windows系统中，这种文件的后缀通常是"`.exe`"



## 对PL0编译程序的修改之处：

1. objecttyp = (constant,variable,prosedure);   {objecttyp的宏定义为一个枚举}

```
Syntax error, "BEGIN" expected but "OBJECT" found
Syntax error, "identifier" expected but "PROCEDURE" found
```

2. 

   variable, procedure : (level, adr : integer) {如果是变量或过程，保存存放层数和偏移地址}

   variable, prosedure : (level, adr : integer) {如果是变量或过程，保存存放层数和偏移地址}

   ```
   Error: Illegal expression
   ```

3. 

   writeln('',  ' ' : cc―1, '↑', n : 2);

   writeln('',  ' ' : cc―1, '^', n : 2);

   ```
   illegal character "'�'" ($E2)
   ```

4. 

   goto 99;

   exit;

   ```
   Error: Goto statements are not allowed between different procedures
   ```

5. 

   while ¬ eoln(input) do

   while not eoln(input) do

6. 增加识别'>'和'<'符号

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

7. 

```pascal
		 else if sym = readsym	{如果读到的符号是read关键字}
					  then begin
							 getsym;	{获取下一个sym类型}
							 if sym = lparen	{read的后面应该接左括号}
							 then
							   repeat	{循环开始}
								 getsym;	{获取下一个sym类型}
								 if sym = ident	{如果第一个sym标识符}
								 then begin	
										i := position(id);	{记录当前符号在符号表中的位置}
										if i = 0	{如果i为0,说明符号表中没有找到id对应的符号}
										then error(11)	{报11号错误}
										else if table[i].kind <> variable {如果找到了,但该符号的类型不是变量}
											 then begin
													error(12);	{报12号错误,不能像常量和过程赋值}
													i := 0	{将i置零}
												  end
											 else with table[i] do	{如果是变量类型}
												   gen(red,lev-level,adr)	{生成一条red指令,读取数据}
									 end
								 else error(4);	{如果左括号后面跟的不是标识符,报4号错误}
								 getsym;	{获取下一个sym类型}
							   until sym <> comma	{知道现在的符号不是都好,循环结束}
							 else error(40);	{如果read后面跟的不是左括号,报40号错误}
							 if sym <> rparen	{如果上述内容之后接的不是右括号}
							 then error(22);	{报22号错误}
							 getsym	{获取下一个sym类型}
						   end
			    else if sym = writesym	{如果读到的符号是write关键字}
				     then begin
					  	  getsym;	{获取下一个sym类型}
						  if sym = lparen	{默认write右边应该加一个左括号}
						  then begin
								 repeat	{循环开始}
								   getsym;	{获取下一个sym类型}
								   expression([rparen,comma]+fsys);	{分析括号中的表达式}
								   gen(wrt,0,0);	{生成一个wrt海曙，用来输出内容}
								 until sym <> comma;	{知道读取到的sym不是逗号}
								 if sym <> rparen	{如果内容结束没有右括号}
								 then error(22);	{报22号错误}
								 getsym	{获取下一个sym类型}
							   end
						  else error(40)	{如果write后面没有跟左括号}
						end;
```

```pascal
  red : begin	{对red指令}
                  writeln('??:');	{输出提示信息}
                  readln(s[base(l)+a]); {读一行数据,读入到相差l层,层内偏移为a的数据栈中的数据的信息}
              end;
          wrt : begin	{对wrt指令}
                  writeln(s[t]);	{输出栈顶的信息}
                  t := t+1	{栈顶上移}
              end
```

