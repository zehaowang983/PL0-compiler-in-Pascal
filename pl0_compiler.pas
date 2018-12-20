program PL0; 
{ PL/0 compiler with code generation }	
{带有代码生成的 PL0 编译程序} 
// label 99; 

{常量定义}
const 
    norw = 13; {保留字的个数} 
    txmax = 100; {标识符表长度} 
    nmax = 14; {数字的最大位数} 
    al = 10; {标识符的长度} 
    amax = 2047; {最大地址} 
    levmax = 3; {程序体嵌套的最大深度} 
    cxmax = 200; {代码数组的大小}

{类型变量定义}
type 
    {symbol的宏定义为一个枚举}
    symbol = (
        nul, ident, number, plus, minus, times, slash, oddsym, eql, neq, lss, 
        leq, gtr, geq, lparen, rparen, comma, semicolon, period, becomes, beginsym, 
        endsym, ifsym, thensym, whilesym, dosym, callsym, constsym, varsym, procsym, readsym, writesym); 
    alfa = packed array [1..al] of char; {alfa宏定义为含有a1个元素的合并数组，为标识符的类型}
    objecttyp = (constant, variable, prosedure); {objecttyp的宏定义为一个枚举}
    symset = set of symbol; {symset为symbol的集合} 
    fct = (lit, opr, lod, sto, cal, int, jmp, jpc, red, wrt); {functions} {fct为一个枚举，其实是PCODE的各条指令}
    instruction = packed record {instruction声明为一个记录类型}
                    f : fct; {功能码} 
                    l : 0..levmax; {相对层数} 
                    a : 0..amax; {相对地址} 
                end; 
                {   
                    LIT 0,a : 取常数 a （读取常量a到数据栈栈顶）
                    OPR 0,a : 执行运算 a 
                    LOD l,a : 取层差为 l 的层﹑相对地址为 a 的变量 （读取变量放到数据栈栈顶，变量的相对地址为a，层次差为l）
                    STO l,a : 存到层差为 l 的层﹑相对地址为 a 的变量 （将数据栈栈顶内容存入变量，变量的相对地址为a，层次差为l）
                    CAL l,a : 调用层差为 l 的过程 （调用过程，过程入口指令为a,层次差为l）
                    INT 0,a : t 寄存器增加 a （数据栈栈顶指针增加a）
                    JMP 0,a : 无条件转移到指令地址 a 处 
                    JPC 0,a : 条件转移到指令地址 a 处
                    red l, a :	读数据并存入变量，
                    wrt 0, 0 : 将栈顶内容输出   
                }

{全局变量定义}
var 
    ch : char; {最近读到的字符} 
    sym : symbol; {最近读到的符号} 
    id : alfa; {最近读到的标识符}
    num : integer; {最近读到的数}
    cc : integer; {当前行的字符计数} 
    ll : integer; {当前行的长度}
    kk, err : integer; {代码数组的当前下标}
    cx : integer; {当前行} 
    line : array [1..81] of char; {当前标识符的字符串}
    a : alfa; {用来存储symbol的变量}
    code : array [0..cxmax] of instruction; {中间代码数组} 
    word : array [1..norw] of alfa; {存放保留字的字符串} 
    wsym : array [1..norw] of symbol; {存放保留字的记号}
    ssym : array [char] of symbol; {存放算符和标点符号的记号} 
    mnemonic : array [fct] of 
                packed array [1..5] of char; {中间代码算符的字符串} 
    declbegsys, statbegsys, facbegsys : symset; {声明开始，表达式开始、项开始的符号集合}
    table : array [0..txmax] of {符号表} 
        record {表中的元素类型是记录类型}
            name : alfa; {元素名}
            case kind : objecttyp of {根据符号的类型保存相应的信息}
                constant : (val : integer); {如果是常量，val中保存常量的值}
                variable, prosedure : (level, adr : integer) {如果是变量或过程，保存存放层数和偏移地址}
            end;

    file_in : text;    {源代码文件}      
    file_out :  text;  {输出文件}
    filename_in : string;  {源程序文件名}
    filename_out : string; {输出文件名}


procedure error (n : integer);  {错误处理程序}
    begin 
        writeln( file_out,'****', ' ':cc-1, '^', n:2 );{cc 为当前行已读的字符数, n 为错误号,报错提示信息，'↑'指向出错位置，并提示错误类型}
        err := err + 1 {错误数 err 加 1} 
    end {error};
    

procedure getsym; {词法分析程序}
    var i, j, k : integer; {声明计数变量}
    procedure getch ; {取下一字符} 
        begin 
            if cc = ll  {如果 cc 指向行末,读完一行（行指针与该行长度相等）} 
            then begin {开始读取下一行}
                if eof(file_in) {如果已到文件尾} 
                then begin 
                        write(file_out,'PROGRAM INCOMPLETE'); {报错}
                        close(file_in);	{关闭文件}
                        exit; {退出}
                    end; 
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
            end; 
            cc := cc + 1; {行指针+1}
            ch := line[cc] {ch 取 line 中下一个字符} 
        end {getch}; {结束读取下一字符}
    
    begin {getsym} {开始标识符识别}
        while ch = ' ' do 
            getch; {跳过无用空白} 
        if ch in ['a'..'z'] {标识符或保留字}
        then begin  
                k := 0; 
                repeat {处理字母开头的字母﹑数字串} 
                    if k < al {如果k的大小小于标识符的最大长度}
                    then begin 
                        k:= k + 1; 
                        a[k] := ch {将ch写入标识符暂存变量a}
                    end; 
                    getch 
                until not (ch in ['a'..'z','0'..'9']); {直到读出的不是数字或字母的时候，标识符结束}

                if k >= kk {后一个标识符大于等于前一个的长度}
                then kk := k {kk记录当前标识符的长度k}
                else repeat {如果标识符长度不是最大长度, 后面补空白} 
                        a[kk] := ' ';
                        kk := kk-1
                    until kk = k; 
                        
                id := a; {id 中存放当前标识符或保留字的字符串} 
                i := 1; {i指向第一个保留字}
                j := norw; {j为保留字的最大数目}

                {用二分查找法在保留字表中找当前的标识符id} 
                repeat 
                    k := (i+j) div 2; 
                    if id <= word[k] then j := k-1;
                    if id >= word[k] then i := k+1
                until i > j; 
                {如果找到, 当前记号 sym 为保留字, 否则 sym 为标识符} 
                if i-1 > j
                then sym := wsym[k] 
                else sym := ident 
            end 

        else if ch in ['0'..'9'] {如果字符是数字}
        then begin
                k := 0; {记录数字的位数}
                num := 0; 
                sym := number; {当前记号 sym 为数字} 
                repeat {计算数字串的值} 
                    num := 10*num+(ord(ch)-ord('0')); {ord(ch)和 ord(0)是 ch 和 0 在 ASCII 码中的序号} 
                    k := k + 1; 
                    getch; 
                until not (ch in ['0'..'9']); 
                if k > nmax  {当前数字串的长度超过上界,则报告错误}
                then error(30) 
            end 
        
        else if ch = ':' {处理赋值号} 
        then begin 
                getch; 
                if ch = '=' 
                then begin 
                        sym := becomes; {将标识符置为becomes，表示复制}
                        getch 
                    end 
                else sym := nul; {否则，将标识符设置为nul，表示非法}
            end 

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

        else {处理其它算符或标点符号} 
        begin 
            sym := ssym[ch]; 
            getch 
        end 
    end {getsym}; {结束标识符的识别}

procedure gen(x : fct; y, z : integer); {目标代码生成过程,x表示PCODE指令,y,z是指令的两个操作数}
    begin 
        if cx > cxmax {如果当前指令序号>代码的最大长度}
        then begin 
                write(file_out,'PROGRAM TOO LONG'); 
                close(file_in);	{关闭文件}
                exit
            end; 
        with code[cx] do {在代码数组 cx 位置生成一条新代码} 
            begin {instruction类型的三个属性}
                f := x; {功能码} 
                l := y; {层号} 
                a := z {地址} 
            end; 
        cx := cx + 1 {指令序号加 1} 
    end {gen};

procedure test(s1, s2 : symset; n : integer); {测试当前字符合法性过程,用于错误语法处理,若不合法则跳过单词值只读到合法单词为止}
    begin 
        if not (sym in s1) {如果当前记号不属于集合 s1,则报告错误 n} 
        then begin 
            error(n); 
            s1 := s1 + s2; {将s1赋值为s1和s2的集合}
            while not (sym in s1) do 
                getsym {跳过所有不合法的符号,直到当前记号属于 s1∪s2,恢复语法分析工作} 
            end 
        end {test};

procedure block(lev, tx : integer; fsys : symset); {进行语法分析的主程序,lev表示语法分析所在层次,tx是当前符号表指针,fsys是用来恢复错误的单词集合}
    var 
        dx : integer; {本过程数据空间分配下标} 
        tx0 : integer; {本过程标识表起始下标} 
        cx0 : integer; {本过程代码起始下标}

    procedure enter(k : objecttyp); {将对象插入到符号表中}
        begin {把 object 填入符号表中} 
            tx := tx +1; {符号表指针加 1,指向一个空表项} 
            with table[tx] do{在符号表中增加新的一个条目} 
                begin 
                    name := id; {当前标识符的名字} 
                    kind := k; {当前标识符的种类} 
                    case k of 
                        constant : begin {当前标识符是常数名} 
                            if num > amax 
                            then {当前常数值大于上界,则出错} begin 
                                error(30); 
                                num := 0 {将常量置零}
                            end; 
                            val := num {val保存该常量的值}
                        end;

                        variable : begin {当前标识符是变量名} 
                            level := lev; {定义该变量的过程的嵌套层数} 
                            adr := dx; {变量地址为当前过程数据空间栈顶} 
                            dx := dx +1; {栈顶指针加 1} 
                        end;

                        prosedure : level := lev; {本过程的嵌套层数}
                    end
                end 
        end {enter};

    function position(id : alfa) : integer; {返回 id 在符号表的入口}
        var i : integer;
        begin {在标识符表中查标识符 id} 
            table[0].name := id; {在符号表栈的最下方预填标识符 id} 
            i := tx; {符号表栈顶指针} 
            while table[i].name <> id do 
                i := i-1; {从符号表栈顶往下查标识符 id} 
            position := i {若查到,i 为 id 的入口,否则 i=0 } 
        end {position};    

    procedure constdeclaration; {处理常量声明的过程}
        begin 
            if sym = ident 
            then {当前记号是常数名} begin 
                getsym; 
                if sym in [eql, becomes] 
                then {当前记号是等号或赋值号} begin 
                    if sym = becomes 
                    then error(1); {如果当前记号是赋值号,则出错,因为常量不能被赋值} 
                    getsym; 
                    if sym = number 
                    then {等号后面是常数} begin 
                            enter(constant); {将常数名加入符号表} 
                            getsym 
                        end 
                    else error(2) {等号后面不是常数出错} 
                end 
                else error(3) {标识符后不是等号或赋值号出错}
            end
            else error(4){常数说明中没有常数名标识符}
        end {constdeclaration};

    procedure vardeclaration; {变量声明要求第一个sym为标识符}
        begin 
            if sym = ident 
            then {如果当前记号是标识符} begin 
                    enter(variable); {将该变量名加入符号表的下一条目} 
                    getsym 
                end 
            else error(4) {如果变量说明未出现标识符,则出错} 
        end {vardeclaration};

    procedure listcode; {列出PCODE的过程}
        var i : integer; 
        begin {列出本程序体生成的代码} 
            for i := cx0 to cx-1 do {cx0: 本过程第一个代码的序号, cx―1: 本过程最后一个代码的序号}  
                with code[i] do {打印第 i 条代码} 
                    {i: 代码序号; mnemonic[f]: 功能码的字符串; l: 相对层号(层差); a: 相对地址或运算号码} 
                    {格式化输出}
                    writeln(file_out, i:5, mnemonic[f] : 7, l : 3, a : 5) 
        end {listcode};

    procedure statement(fsys : symset); {语句处理的过程}
        var i, cx1, cx2 : integer; 
        
        procedure expression(fsys : symset); {处理表达式的过程}
            var addop : symbol; 
                procedure term(fsys : symset);  {处理项的过程}
                    var mulop : symbol; 

                    procedure factor(fsys : symset); {处理因子的处理程序}
                        var i : integer; 
                        begin 
                            test(facbegsys, fsys, 24); {测试当前的记号是否因子的开始符号, 否则出错, 跳过一些记号}
                            while sym in facbegsys do {循环处理因子}
                                begin 
                                    if sym = ident 
                                    then {当前记号是标识符} begin 
                                            i := position(id); {查符号表,返回 id 的入口} 
                                            if i = 0 {若在符号表中查不到 id, 则出错, 否则,做以下工作} 
                                            then error(11) 
                                            else 
                                                with table[i] do {对第i个表项的内容}
                                                    case kind of 
                                                        constant : gen(lit, 0, val); {若 id 是常数, 生成LIT指令,操作数为0,val,将常数 val 取到栈顶}
                                                        variable : gen(lod,lev-level,adr); {若 id 是变量, 生成LOD指令,将该变量取到栈顶; lev: 当前语句所在过程的层号; level: 定义该变量的过程层号; adr: 变量在其过程的数据空间的相对地址} 
                                                        prosedure : error(21) {若 id 是过程名, 则出错} 
                                                end; 
                                            getsym {取下一记号} 
                                        end 

                                    else if sym = number 
                                    then {当前记号是数字} begin 
                                        if num > amax 
                                        then {若数值越界,则出错} begin 
                                                error(30); 
                                                num := 0 
                                            end; 
                                        gen(lit, 0, num); {生成一条LIT指令, 将常数 num 取到栈顶} 
                                        getsym {取下一记号} 
                                        end 
                                        
                                    else if sym = lparen 
                                    then {如果当前记号是左括号} begin 
                                            getsym; {取下一记号} 
                                            expression([rparen]+fsys);	{调用表达式的过程来处理,递归下降子程序方法}
                                            if sym = rparen {如果当前记号是右括号, 则取下一记号,否则出错} 
                                            then getsym
                                            else error(22) 
                                    end; 

                                test(fsys, [lparen], 23) {测试当前记号是否同步, 否则出错, 跳过一些记号} 
                                end {while} 
                        end {factor};


                    begin {term} {项的分析过程开始}
                        factor(fsys+[times, slash]); {处理项中第一个因子} 
                        while sym in [times, slash] do {当前记号是“乘”或“除”号}
                            begin 
                                mulop := sym; {运算符存入 mulop} 
                                getsym; {取下一记号} 
                                factor(fsys+[times, slash]); {处理因子分析程序分析运算符后的因子} 
                                if mulop = times 
                                then gen(opr, 0, 4) {若 mulop 是“乘”号,生成一条乘法指令} 
                                else gen(opr, 0, 5) {否则, mulop 是除号, 生成一条除法指令} 
                            end
                    end {term};
                    
            begin {expression} {表达式的分析过程开始}
                if sym in [plus, minus] 
                then {若第一个记号是加号或减号} begin 
                        addop := sym; {“+”或“―”存入 addop} 
                        getsym; 
                        term(fsys+[plus, minus]); {处理负号后面的项} 
                        if addop = minus 
                        then gen(opr, 0, 1) {若第一个项前是负号, 生成一条“负运算”指令} 
                    end 
                else term(fsys+[plus, minus]); {第一个记号不是加号或减号, 则处理一个项} 
                while sym in [plus, minus] do {若当前记号是加号或减号,可以接若干个term,使用操作符+-相连} 
                    begin 
                        addop := sym; {当前算符存入 addop} 
                        getsym; {取下一记号} 
                        term(fsys+[plus, minus]); {处理运算符后面的项}  
                        if addop = plus 
                        then gen(opr, 0, 2) {若 addop 是加号, 生成一条加法指令} 
                        else gen(opr, 0, 3) {否则, addop 是减号, 生成一条减法指令} 
                    end 
            end {expression};

            procedure condition(fsys : symset); {条件处理过程}
                var relop : symbol;
                begin
                    if sym = oddsym 
                    then {如果当前记号是"odd"} begin
                        getsym;  {取下一记号}
                        expression(fsys); {处理算术表达式}
                        gen(opr, 0, 6) {生成指令,判定表达式的值是否为奇数,是,则取"真";不是, 则取"假"}
                    end 

                    else {如果当前记号不是"odd"} begin
                        expression([eql, neq, lss, gtr, leq, geq] + fsys); {处理算术表达式,对表达式进行计算}
                        if  not (sym in [eql, neq, lss, leq, gtr, geq]) {如果当前记号不是关系符, 则出错; 否则,做以下工作}
                        then error(20)  
                        else begin
                                relop := sym; {关系符存入relop} 
                                getsym; {取下一记号} 
                                expression(fsys); {处理关系符右边的算术表达式}
                                case relop of
                                    eql : gen(opr, 0, 8); {生成指令, 判定两个表达式的值是否相等}
                                    neq : gen(opr, 0, 9); {生成指令, 判定两个表达式的值是否不等}
                                    lss : gen(opr, 0, 10);{生成指令, 判定前一表达式是否小于后一表达式}
                                    geq : gen(opr, 0, 11);{生成指令, 判定前一表达式是否大于等于后一表达式}
                                    gtr : gen(opr, 0, 12);{生成指令, 判定前一表达式是否大于后一表达式}
                                    leq : gen(opr, 0, 13);{生成指令, 判定前一表达式是否小于等于后一表达式}
                                end
                            end
                        end
                end {condition};

        begin {statement} {声明语句处理过程}
            if sym = ident then {处理赋值语句}
            begin  
                i := position(id); {在符号表中查id, 返回id在符号表中的入口}
                if i = 0 then error(11) {若在符号表中查不到id, 则出错, 否则做以下工作}

                else if table[i].kind <> variable then {若标识符id不是变量, 则出错} 
                    begin 
                        error(12); 
                        i := 0; {对非变量赋值} 
                    end;
                
                getsym; {取下一记号}
                if sym = becomes then getsym else error(13); {若当前是赋值号, 取下一记号, 否则出错}
                expression(fsys); {处理表达式}
                if i <> 0 then {若赋值号左边的变量id有定义}
                    with table[i] do 
                    {lev: 当前语句所在过程的层号;
                    level: 定义变量id的过程的层号;
                    adr: 变量id在其过程的数据空间的相对地址}
                    gen(sto,lev-level,adr) {生成一条STO存数指令, 将栈顶(表达式)的值存入变量id中;}
            end 
            
            else if sym = callsym then {处理过程调用语句}
            begin  
                getsym; {取下一记号}
                if sym <> ident then error(14){如果下一记号不是标识符(过程名),则出错,否则做以下工作}
                else begin 
                        i := position(id); {查符号表,返回id在表中的位置}
                        if i = 0 then error(11) else {如果在符号表中查不到, 则出错; 否则,做以下工作}
                        with table[i] do
                            if kind = prosedure {如果在符号表中id是过程名} then
                                gen(cal,lev-level,adr)
                                {生成一条过程调用指令;
                                lev: 当前语句所在过程的层号
                                level: 定义过程名id的层号;
                                adr: 过程id的代码中第一条指令的地址}
                            else error(15); {若id不是过程名,则出错}
                        getsym {取下一记号}
                    end
            end 
            
            else if sym = ifsym then {处理条件语句}
            begin
                getsym; {取下一记号} 
                condition([thensym, dosym]+fsys); {处理条件表达式}
                if sym = thensym then getsym else error(16);{如果当前记号是"then",则取下一记号; 否则出错}
                cx1 := cx; {cx1记录下一代码的地址} 
                gen(jpc, 0, 0); {生成指令,表达式为"假"转到某地址(待填),否则顺序执行}
                statement(fsys); {处理一个语句}
                code[cx1].a := cx 
                {将下一个指令的地址回填到上面的jpc指令地址栏}
            end 
            
            else if sym = beginsym then {处理语句序列}
            begin
                getsym;  
                statement([semicolon, endsym]+fsys); {取下一记号, 处理第一个语句}
                while sym in [semicolon]+statbegsys do  {如果当前记号是分号或语句的开始符号,则做以下工作}
                    begin
                        if sym = semicolon then getsym else error(10); {如果当前记号是分号,则取下一记号, 否则出错}
                        statement([semicolon, endsym]+fsys) {处理下一个语句}
                    end;
                if sym = endsym then getsym else error(17) {如果当前记号是"end",则取下一记号,否则出错}
            end
            
            else if sym = whilesym then {处理循环语句}
            begin
                cx1 := cx; {cx1记录下一指令地址,即条件表达式的第一条代码的地址} 
                getsym; {取下一记号}
                condition([dosym]+fsys); {处理条件表达式}
                cx2 := cx; {记录下一指令的地址} 
                gen(jpc, 0, 0); {生成一条指令,表达式为"假"转到某地址(待回填), 否则顺序执行}
                if sym = dosym then getsym else error(18);{如果当前记号是"do",则取下一记号, 否则出错}
                statement(fsys); {处理"do"后面的语句}
                gen(jmp, 0, cx1); {生成无条件转移指令, 转移到"while"后的条件表达式的代码的第一条指令处} 
                code[cx2].a := cx {把下一指令地址回填到前面生成的jpc指令的地址栏}
            end

            else if sym = readsym	{处理read关键字} then 
            begin
                getsym;	{获取下一个sym类型}
                if sym = lparen	{read的后面应该接左括号} 
                then begin
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
                        until sym <> comma	{直到符号不是逗号,循环结束}
                    end
                else error(40);	{如果read后面跟的不是左括号,报40号错误}
                if sym <> rparen	{如果上述内容之后接的不是右括号}
                then error(22);	{报22号错误}
                getsym	{获取下一个sym类型}
            end

            else if sym = writesym	{处理write关键字} then 
            begin
                getsym;	{获取下一个sym类型}
                if sym = lparen	{默认write右边应该加一个左括号}
                then begin
                        repeat	{循环开始}
                            getsym;	{获取下一个sym类型}
                            expression([rparen,comma]+fsys);	{分析括号中的表达式}
                            gen(wrt,0,0);	{生成一个wrt，用来输出内容}
                        until sym <> comma;	{知道读取到的sym不是逗号}
                        if sym <> rparen	{如果内容结束没有右括号}
                        then error(22);	{报22号错误}
                        getsym	{获取下一个sym类型}
                    end
                else error(40)	{如果write后面没有跟左括号}
            end;

            test(fsys, [ ], 19) {测试下一记号是否正常, 否则出错, 跳过一些记号}
        end {statement};

    begin {block}
        dx := 3; {本过程数据空间栈顶指针} 
        tx0 := tx; {标识符表的长度(当前指针)} 
        table[tx].adr := cx; {本过程名的地址, 即下一条指令的序号}
        gen(jmp, 0, 0); {生成一条转移指令}
        if lev > levmax then error(32); {如果当前过程层号>最大层数, 则出错}

        repeat
            if sym = constsym then {处理常数说明语句}
            begin  
                getsym;
                repeat 
                    constdeclaration; {处理一个常数说明}
                    while sym = comma do {如果当前记号是逗号}
                        begin 
                            getsym; 
                            constdeclaration 
                        end; {处理下一个常数说明}
                    
                    if sym = semicolon then getsym else error(5) {如果当前记号是分号,则常数说明已处理完, 否则出错}
                until sym <> ident {跳过一些记号, 直到当前记号不是标识符(出错时才用到)}
            end;
            
            if sym = varsym then {当前记号是变量说明语句开始符号}
            begin  
                getsym;
                repeat 
                    vardeclaration; {处理一个变量说明}
                    while sym = comma do {如果当前记号是逗号}
                        begin  
                            getsym;  
                            vardeclaration  
                        end; {处理下一个变量说明}
                    if sym = semicolon then getsym else error(5){如果当前记号是分号,则变量说明已处理完, 否则出错}
                until sym <> ident; {跳过一些记号, 直到当前记号不是标识符(出错时才用到)}
            end;
            
            while sym = procsym do {处理过程说明}
            begin  
                getsym;
                if sym = ident then {如果当前记号是过程名}
                begin  
                    enter(prosedure);  
                    getsym  
                end {把过程名填入符号表}
                else error(4); {否则, 缺少过程名出错}

                if sym = semicolon then 
                    getsym 
                else error(5);{当前记号是分号, 则取下一记号,否则,过程名后漏掉分号出错}
                block(lev+1, tx, [semicolon]+fsys); {处理过程体}
                {lev+1: 过程嵌套层数加1; tx: 符号表当前栈顶指针,也是新过程符号表起始位置; [semicolon]+fsys: 过程体开始和末尾符号集}

                if sym = semicolon then {如果当前记号是分号}
                begin  
                    getsym; {取下一记号}
                    test(statbegsys+[ident, procsym], fsys, 6)
                    {测试当前记号是否语句开始符号或过程说明开始符号,否则报告错误6, 并跳过一些记号}
                end
                else error(5) {如果当前记号不是分号,则出错}
            end; {while}

            test(statbegsys+[ident], declbegsys, 7) {检测当前记号是否语句开始符号, 否则出错, 并跳过一些记号}

        until not ( sym in declbegsys );{回到说明语句的处理(出错时才用),直到当前记号不是说明语句的开始符号}

        code[table[tx0].adr].a := cx;  
        {table[tx0].adr是本过程名的第1条代码(jmp, 0, 0)的地址,本语句即是将下一代码(本过程语句的第
        1条代码)的地址回填到该jmp指令中,得(jmp, 0, cx)}
        with table[tx0] do {本过程名的第1条代码的地址改为下一指令地址cx}
            begin  
                adr := cx; {代码开始地址}
            end;
        cx0 := cx; {cx0记录起始代码地址}
        gen(int, 0, dx); {生成一条指令, 在栈顶为本过程留出数据空间}
        statement([semicolon, endsym]+fsys); {处理一个语句}
        gen(opr, 0, 0); {生成返回指令}
        test(fsys, [ ], 8); {测试过程体语句后的符号是否正常,否则出错}
        listcode; {打印本过程的中间代码序列}
    end  {block};

procedure  interpret; {解释执行程序}
    const  stacksize = 500; {运行时数据空间(栈)的上界}
    var  
        p, b, t : integer; {程序地址寄存器, 基地址寄存器,栈顶地址寄存器}
        i : instruction; {指令寄存器}
        s : array [1..stacksize] of integer; {数据存储栈}

    function  base(l : integer) : integer; {计算基地址的函数}
        var  b1 : integer; {声明计数变量}
        begin
            b1 := b; {顺静态链求层差为l的外层的基地址}
            while l > 0 do
                begin  
                    b1 := s[b1];  
                    l := l-1
                end;
            base := b1
        end {base};

    begin  
        writeln(file_out,'START PL/0');
        t := 0; {栈顶地址寄存器}
        b := 1; {基地址寄存器}
        p := 0; {程序地址寄存器}
        s[1] := 0;  s[2] := 0;  s[3] := 0;  {最外层主程序数据空间栈最下面预留三个单元}
        {每个过程运行时的数据空间的前三个单元是:SL, DL, RA;
        SL: 指向本过程静态直接外层过程的SL单元;
        DL: 指向调用本过程的过程的最新数据空间的第一个单元;
        RA: 返回地址 }

        repeat
            i := code[p]; {i取程序地址寄存器p指示的当前指令}
            p := p+1; {程序地址寄存器p加1,指向下一条指令}
            with i do
                case f of
                    lit : begin {当前指令是取常数指令(lit, 0, a)}
                            t := t+1;  
                            s[t] := a
                        end; {栈顶指针加1, 把常数a取到栈顶}

                    opr : case a of {当前指令是运算指令(opr, 0, a)}
                        0 : begin {a=0时,是返回调用过程指令}
                                t := b-1; {恢复调用过程栈顶} 
                                p := s[t+3]; {程序地址寄存器p取返回地址,即获得return address} 
                                b := s[t+2]; {基地址寄存器b指向调用过程的基地址,即获得了return之后的基址}
                            end;
                        1 : s[t] := -s[t]; {一元负运算, 栈顶元素的值反号}
                        2 : begin {加法} {将栈顶和次栈顶中的数值求和放入新的栈顶}
                                t := t-1;  s[t] := s[t] + s[t+1] 
                            end;
                        3 : begin {减法}
                                t := t-1;  s[t] := s[t]-s[t+1]
                            end;
                        4 : begin {乘法}
                                t := t-1;  s[t] := s[t] * s[t+1]
                            end;
                        5 : begin {整数除法}
                                t := t-1;  s[t] := s[t] div s[t+1]
                            end;
                        6 : s[t] := ord(odd(s[t])); {算s[t]是否奇数, 是则s[t]=1, 否则s[t]=0}
                        8 : begin  t := t-1;
                                s[t] := ord(s[t] = s[t+1])
                            end; {判两个表达式的值是否相等,是则s[t]=1, 否则s[t]=0}
                        9: begin  t := t-1;
                                s[t] := ord(s[t] <> s[t+1])
                            end; {判两个表达式的值是否不等,是则s[t]=1, 否则s[t]=0}
                        10 : begin  t := t-1;
                                s[t] := ord(s[t] < s[t+1])
                            end; {判前一表达式是否小于后一表达式,是则s[t]=1, 否则s[t]=0}
                        11: begin  t := t-1;
                                s[t] := ord(s[t] >= s[t+1])
                            end; {判前一表达式是否大于或等于后一表达式,是则s[t]=1, 否则s[t]=0}
                        12 : begin  t := t-1;
                                s[t] := ord(s[t] > s[t+1])
                            end; {判前一表达式是否大于后一表达式,是则s[t]=1, 否则s[t]=0}
                        13 : begin  t := t-1;
                                s[t] := ord(s[t] <= s[t+1])
                            end; {判前一表达式是否小于或等于后一表达式,是则s[t]=1, 否则s[t]=0}
                        end;
                    lod : begin {当前指令是取变量指令(lod, l, a)}
                            t := t + 1;  
                            s[t] := s[base(l) + a]
                            {栈顶指针加1, 根据静态链SL,将层差为l,相对地址为a的变量值取到栈顶}
                        end;
                    sto : begin {当前指令是保存变量值(sto, l, a)指令}
                            s[base(l) + a] := s[t];  
                            {writeln(s[t]);}
                            {根据静态链SL,将栈顶的值存入层差为l,相对地址为a的变量中}
                            t := t-1 {栈顶指针减1}
                        end;
                    cal : begin {当前指令是(cal, l, a)}
                            {为被调用过程数据空间建立连接数据}
                            s[t+1] := base(l); {根据层差l找到本过程的静态直接外层过程的数据空间的SL单元,将其地址存入本过程新的数据空间的SL单元} 
                            s[t+2] := b; {调用过程的数据空间的起始地址存入本过程DL单元}
                            s[t+3] := p; {调用过程cal指令的下一条的地址存入本过程RA单元}
                            b := t+1; {b指向被调用过程新的数据空间起始地址} 
                            p := a {指令地址寄存储器指向被调用过程的地址a}
                        end;
                    int : t := t + a; {若当前指令是(int, 0, a), 则数据空间栈顶留出a大小的空间}
                    jmp : p := a; {若当前指令是(jmp, 0, a), 则程序转到地址a执行}
                    jpc : begin {当前指令是(jpc, 0, a)}
                            if s[t] = 0 then p := a;{如果当前运算结果为"假"(0), 程序转到地址a执行, 否则顺序执行}
                            t := t-1 {数据栈顶指针减1}
                        end;

                    red : begin	{对red指令}
                            writeln(file_out,'read: ');	{输出提示信息}
                            readln(s[base(l)+a]); {读一行数据,读入到相差l层,层内偏移为a的数据栈中的数据的信息}
                        end;
                    wrt : begin	{对wrt指令}
                            writeln(file_out,s[t]);	{输出栈顶的信息}
                            t := t+1	{栈顶上移}
                        end
                end {with, case}
        until p = 0; {程序一直执行到p取最外层主程序的返回地址0时为止}
        writeln(file_out,'END PL/0');
    end {interpret};


begin  {主程序}
    writeln('请输入PL0源文件名 : ');
    readln(filename_in);	
    writeln('请输入输出文件名 : ');
    readln(filename_out);	
    assign(file_in,filename_in);
    assign(file_out,filename_out);	{将文件名字符串变量赋值给文件变量}
    reset(file_in);
    rewrite(file_out);	{打开文件}

    for ch := 'A' to ';' do  ssym[ch] := nul; {ASCII码的顺序}
    
    word[1] := 'begin     '; word[2] := 'call      ';
    word[3] := 'const     '; word[4] := 'do        ';
    word[5] := 'end       '; word[6] := 'if        ';
    word[7] := 'odd       '; word[8] := 'procedure ';
    word[9] := 'then      '; word[10] := 'var       ';
    word[11] := 'while     ';word[12] := 'write     ';
    word[13] := 'read    ';{保留字表改为小写字母,所有字符都预留的相同的长度}

    wsym[1] := beginsym;   wsym[2] := callsym;
    wsym[3] := constsym;   wsym[4] := dosym;
    wsym[5] := endsym;     wsym[6] := ifsym;
    wsym[7] := oddsym;     wsym[8] := procsym;
    wsym[9] := thensym;    wsym[10] := varsym;
    wsym[11] := whilesym;  wsym[12] := writesym;
    wsym[13] := readsym; {保留字对应的标识符,添加read和write的保留字}

    ssym['+'] := plus;      ssym['-'] := minus;
    ssym['*'] := times;     ssym['/'] := slash;
    ssym['('] := lparen;    ssym[')'] := rparen;
    ssym['='] := eql;       ssym[','] := comma;
    ssym['.'] := period;    ssym['<'] := lss;      
    ssym['>'] := gtr;       ssym[';'] := semicolon; {算符和标点符号的记号}

    mnemonic[lit] := 'LIT  ';     mnemonic[opr] := 'OPR  ';
    mnemonic[lod] := 'LOD  ';    mnemonic[sto] := 'STO  ';
    mnemonic[cal] := 'CAL  ';    mnemonic[int] := 'INT  ';
    mnemonic[jmp] := 'JMP  ';    mnemonic[jpc] := 'JPC  '; 
    mnemonic[red] := 'RED  '; mnemonic[wrt] := 'WRT  ';{中间代码指令的字符串，长度为5}
  
    declbegsys := [constsym, varsym, procsym]; {说明语句的开始符号}
    statbegsys := [beginsym, callsym, ifsym, whilesym]; {语句的开始符号}
    facbegsys := [ident, number, lparen]; {因子的开始符号}
    err := 0; {发现错误的个数}
    cc := 0; {当前行中输入字符的指针} 
    cx := 0; {代码数组的当前指针} 
    ll := 0; {输入当前行的长度} 
    ch := ' '; {当前输入的字符}
    kk := al; {标识符的长度}
    getsym; {取下一个记号}
    block(0, 0, [period]+declbegsys+statbegsys); {处理程序体}
    if sym <> period then error(9); {如果当前记号不是句号, 则出错}
    if err = 0 then interpret {如果编译无错误, 则解释执行中间代码}
    else write('ERRORS IN PL/0 PROGRAM');

    close(file_in);	
    close(file_out);	{关闭文件}
end.










                    
