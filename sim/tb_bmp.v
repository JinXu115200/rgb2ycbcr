`timescale 1ns / 1ns

module tb_bmp;
 
integer iBmpFileId;                 //输入BMP图片
integer oBmpFileId;                 //输出BMP图片
integer oTxtFileId;                 //输入TXT文本
        
integer iIndex = 0;                 //输出BMP数据索引
integer pixel_index = 0;            //输出像素数据索引 
        
integer iCode;      
        
integer iBmpWidth;                  //输入BMP 宽度
integer iBmpHight;                  //输入BMP 高度
integer iBmpSize;                   //输入BMP 字节数
integer iDataStartIndex;            //输入BMP 像素数据偏移量
    
reg [ 7:0] rBmpData [0:2000000];    //用于寄存输入BMP图片中的字节数据（包括54字节的文件头）
reg [ 7:0] Vip_BmpData [0:2000000]; //用于寄存视频图像处理之后 的BMP图片 数据 
reg [31:0] rBmpWord;                //输出BMP图片时用于寄存数据（以word为单位，即4byte）

reg [ 7:0] pixel_data;              //输出视频流时的像素数据

reg clk;
reg rst_n;

reg [ 7:0] vip_pixel_data [0:921600];   //320x240x3

 
initial begin

    //分别打开 输入/输出BMP图片，以及输出的Txt文本
	iBmpFileId = $fopen("Q:\\user\\XuJin\\LOD\\FPGA\\rgb2ycbcr\\sim\\Dog_Breeds.bmp","rb");
//  iBmpFileId = $fopen("Q:\\user\\XuJin\\LOD\\FPGA\\rgb2ycbcr\\sim\\fengjing_320x240.bmp","rb");
	oBmpFileId = $fopen("Q:\\user\\XuJin\\LOD\\FPGA\\rgb2ycbcr\\sim\\output_file.bmp","wb+");
	oTxtFileId = $fopen("Q:\\user\\XuJin\\LOD\\FPGA\\rgb2ycbcr\\sim\\output_file.txt","w+");

    //将输入BMP图片加载到数组中
	iCode = $fread(rBmpData,iBmpFileId);
 
    //根据BMP图片文件头的格式，分别计算出图片的 宽度 /高度 /像素数据偏移量 /图片字节数
	iBmpWidth       = {rBmpData[21],rBmpData[20],rBmpData[19],rBmpData[18]};
	iBmpHight       = {rBmpData[25],rBmpData[24],rBmpData[23],rBmpData[22]};
	iBmpSize        = {rBmpData[ 5],rBmpData[ 4],rBmpData[ 3],rBmpData[ 2]};
	iDataStartIndex = {rBmpData[13],rBmpData[12],rBmpData[11],rBmpData[10]};
    
    //关闭输入BMP图片
	$fclose(iBmpFileId);
    
    //将数组中的数据写到输出Txt文本中
	$fwrite(oTxtFileId,"%p",rBmpData);
    //关闭Txt文本
    $fclose(oTxtFileId);
        
    
    //延迟2ms，等待第一帧VIP处理结束
    #13000000    
    //加载图像处理后，BMP图片的文件头和像素数据
	for (iIndex = 0; iIndex < iBmpSize; iIndex = iIndex + 1) begin
		if(iIndex < 54)
            Vip_BmpData[iIndex] = rBmpData[iIndex];
        else
            Vip_BmpData[iIndex] = vip_pixel_data[iIndex-54];
	end
    
    //将数组中的数据写到输出BMP图片中    
	for (iIndex = 0; iIndex < iBmpSize; iIndex = iIndex + 4) begin
		rBmpWord = {Vip_BmpData[iIndex+3],Vip_BmpData[iIndex+2],Vip_BmpData[iIndex+1],Vip_BmpData[iIndex]};
		$fwrite(oBmpFileId,"%u",rBmpWord);
	end
    //关闭输出BMP图片
	$fclose(oBmpFileId);
    
end
 
//初始化时钟和复位信号
initial begin
    clk     = 1;
    rst_n   = 0;
    #110
    rst_n   = 1;
end 

//产生50MHz时钟
always #10 clk = ~clk;
 
//在时钟驱动下，从数组中读出像素数据
always@(posedge clk or negedge rst_n)begin
    if(!rst_n) begin
        pixel_data  <=  8'd0;
        pixel_index <=  0;
    end
    else begin
        pixel_data  <=  rBmpData[pixel_index];
        pixel_index <=  pixel_index+1;
    end
end
 
 
////////////////////////////////////////////产生摄像头时序 

wire		cmos_vsync ;
reg			cmos_href;
wire        cmos_clken;
reg	[23:0]	cmos_data;			 

reg [31:0]  cmos_index;

parameter [10:0] IMG_HDISP = 11'd640;
parameter [10:0] IMG_VDISP = 11'd480;

localparam H_SYNC = 11'd5;		
localparam H_BACK = 11'd5;		
localparam H_DISP = IMG_HDISP;	
localparam H_FRONT = 11'd5;		
localparam H_TOTAL = H_SYNC + H_BACK + H_DISP + H_FRONT;

localparam V_SYNC = 11'd1;		
localparam V_BACK = 11'd0;		
localparam V_DISP = IMG_VDISP;	
localparam V_FRONT = 11'd1;		
localparam V_TOTAL = V_SYNC + V_BACK + V_DISP + V_FRONT;

//---------------------------------------------
//水平计数器
reg	[10:0]	hcnt;
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		hcnt <= 11'd0;
	else
		hcnt <= (hcnt < H_TOTAL - 1'b1) ? hcnt + 1'b1 : 11'd0;
end

//---------------------------------------------
//竖直计数器
reg	[10:0]	vcnt;
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		vcnt <= 11'd0;		
	else begin
		if(hcnt == H_TOTAL - 1'b1)
			vcnt <= (vcnt < V_TOTAL - 1'b1) ? vcnt + 1'b1 : 11'd0;
		else
			vcnt <= vcnt;
    end
end

//---------------------------------------------
//场同步
reg	cmos_vsync_r;
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		cmos_vsync_r <= 1'b0;			//H: Vaild, L: inVaild
	else begin
		if(vcnt <= V_SYNC - 1'b1)
			cmos_vsync_r <= 1'b0; 	//H: Vaild, L: inVaild
		else
			cmos_vsync_r <= 1'b1; 	//H: Vaild, L: inVaild
    end
end
assign	cmos_vsync	= cmos_vsync_r;


//---------------------------------------------
//Image data href vaild  signal
wire	frame_valid_ahead =  ( vcnt >= V_SYNC + V_BACK  && vcnt < V_SYNC + V_BACK + V_DISP
                            && hcnt >= H_SYNC + H_BACK  && hcnt < H_SYNC + H_BACK + H_DISP ) 
						? 1'b1 : 1'b0;
      
reg			cmos_href_r;      
always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		cmos_href_r <= 0;
	else begin
		if(frame_valid_ahead)
			cmos_href_r <= 1;
		else
			cmos_href_r <= 0;
    end
end

always@(posedge clk or negedge rst_n) begin
	if(!rst_n)
		cmos_href <= 0;
	else
        cmos_href <= cmos_href_r;
end

assign cmos_clken = cmos_href;

//-------------------------------------
//从数组中以视频格式输出像素数据
wire [10:0] x_pos;
wire [10:0] y_pos;

assign x_pos = frame_valid_ahead ? (hcnt - (H_SYNC + H_BACK )) : 0;
assign y_pos = frame_valid_ahead ? (vcnt - (V_SYNC + V_BACK )) : 0;


always@(posedge clk or negedge rst_n)begin
   if(!rst_n) begin
       cmos_index   <=  0;
       cmos_data    <=  24'd0;
   end
   else begin
       cmos_index   <=  y_pos * 1920  + x_pos*3 + 54;        //  3*(y*320 + x) + 54
       cmos_data    <=  {rBmpData[cmos_index], rBmpData[cmos_index+1] , rBmpData[cmos_index+2]};
   end
end

//RGB TO YCbCr
wire 			per_frame_vsync	=	cmos_vsync ;
wire 			per_frame_href	=	cmos_href;	
wire 			per_frame_clken	=	cmos_clken;	
wire [23:0]		pix_data_in = 		cmos_data;

wire [23:0]		gray_data;
wire 			post_frame_clken;
wire 			post_frame_vsync;
wire			post_frame_href;	


 rgb2ycbcr rgb2ycbcr_inst 
 (
    // System host?
    .sys_clk             (clk	),   			//system operating clock
    .sys_rst_n           (rst_n	),   			//reset signal with low level valid

    
    .per_frame_href      (per_frame_href),   	//Horizontal Synchronization signal for input image
    .per_frame_vsync     (per_frame_vsync),   	//Vertikale Synchronization signal for input image
    .pix_data_in         (pix_data_in),   		//rgb pix data
    .per_frame_clken     (per_frame_clken),   

    
    .gray_data           (gray_data),   		//YCbCr pix data
    .post_frame_clken    (post_frame_clken),    
    .post_frame_vsync    (post_frame_vsync),    //Vertikale Synchronization signal for output image
    .post_frame_href     (post_frame_href)      //Horizontal Synchronization signal for output image   
 
);

//
wire 		vip_out_frame_vsync;   
wire 		vip_out_frame_href ;   
wire 		vip_out_frame_clken;

assign 		vip_out_frame_vsync = post_frame_vsync;
assign 		vip_out_frame_href  = post_frame_href ;
assign 		vip_out_frame_clken = post_frame_clken;

wire [7:0]	vip_out_img_R     ;
wire [7:0]	vip_out_img_G     ;
wire [7:0]	vip_out_img_B     ;

assign vip_out_img_R = gray_data [23:16];
assign vip_out_img_G = gray_data [15:8]	;
assign vip_out_img_B = gray_data [7:0]	;

reg [31:0] vip_cnt;
 
reg         vip_vsync_r;    //寄存VIP输出的场同步 
reg         vip_out_en;     //寄存VIP处理图像的使能信号，仅维持一帧的时间

always@(posedge clk or negedge rst_n)begin
   if(!rst_n) 
        vip_vsync_r   <=  1'b0;
   else 
        vip_vsync_r   <=  post_frame_vsync;
end

always@(posedge clk or negedge rst_n)begin
   if(!rst_n) 
        vip_out_en    <=  1'b1;
   else if(vip_vsync_r & (!post_frame_vsync))  //第一帧结束之后，使能拉低
        vip_out_en    <=  1'b0;
end

always@(posedge clk or negedge rst_n)begin
   if(!rst_n) begin
        vip_cnt <=  32'd0;
   end
   else if(vip_out_en) begin
        if(vip_out_frame_href & vip_out_frame_clken) begin
            vip_cnt <=  vip_cnt + 3;
            vip_pixel_data[vip_cnt+0] <= vip_out_img_R;
            vip_pixel_data[vip_cnt+1] <= vip_out_img_G;
            vip_pixel_data[vip_cnt+2] <= vip_out_img_B;
        end
   end
end

endmodule