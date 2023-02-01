module rgb2ycbcr (
    // System host?
    input   wire                sys_clk             ,   //system operating clock
    input   wire                sys_rst_n           ,   //reset signal with low level valid

    // RGB image input port
    input   wire                rgb_hsync           ,   //Horizontal Synchronization signal for input image
    input   wire                rgb_vsync           ,   //Vertikale Synchronization signal for input image
    input   wire    [15:0]      pix_data_in         ,   //rgb pix data
    input   wire                image_data_valid    ,   

    // YCbCr output port   
    output  wire    [23:0]      gray_data           ,   //YCbCr pix data
    output  reg                 ycbcr_valid         ,   
    output  reg                 ycbcr_vsync         ,   //Horizontal Synchronization signal for output image
    output  reg                 ycbcr_hsync             //Vertikale Synchronization signal for output image
 
);


//wire difination
wire [7:0]  R_0  ;
wire [7:0]  G_0  ;
wire [7:0]  B_0  ;

//reg difination
reg  [15:0] R_1  ;   // registor of data in red channel for frist level operation
reg  [15:0] G_1  ;   // registor of data in green channel for frist level operation
reg  [15:0] B_1  ;   // registor of data in blue channel for frist level operation

reg  [15:0] R_2  ;   // registor of data in red channel for second level operation
reg  [15:0] G_2  ;   // registor of data in green channel for second level operation
reg  [15:0] B_2  ;   // registor of data in blue channel for second level operation

reg  [15:0] R_3  ;   // registor of data in red channel for thrid level operation
reg  [15:0] G_3  ;   // registor of data in green channel for thrid level operation
reg  [15:0] B_3  ;   // registor of data in blue channel for thrid level operation

reg  [16:0] Y_1  ;
reg  [16:0] Cb_1 ;
reg  [16:0] Cr_1 ;  

reg  [7:0] Y_2  ;
reg  [7:0] Cb_2 ;
reg  [7:0] Cr_2 ; 

reg  rgb_hsync_ack;
reg  rgb_hsync_ack_1;

reg rgb_vsync_ack;
reg rgb_vsync_ack_1;

reg image_data_valid_ack;
reg image_data_valid_ack_1;

//*******************************************************************************************************************//
//******************************************************main code****************************************************//
//*******************************************************************************************************************//

//pix data with form "RGB565" to "RGB888"
assign R_0 = {pix_data_in [15:11] , pix_data_in [15:13]} ;
assign G_0 = {pix_data_in [10:5] , pix_data_in [10:9]};
assign B_0 = {pix_data_in [4:0] , pix_data_in [4:2]};

//frist level operation: multiplication operation
always@(posedge sys_clk or negedge sys_rst_n)
    begin
        if (sys_rst_n == 1'b0)
            begin
               {R_1, G_1, B_1} <= {16'd0, 16'd0, 16'd0};
               {R_2, G_2, B_2} <= {16'd0, 16'd0, 16'd0};
               {R_3, G_3, B_3} <= {16'd0, 16'd0, 16'd0};
            end
        else 
            begin
                {R_1, G_1, B_1} <= { {R0 * 16'd77} , {G0 * 16'd150} , {B0 * 16'd29} }; 
                {R_2, G_2, B_2} <= { {R0 * 16'd43} , {G0 * 16'd85} , {B0 * 16'd128} };
                {R_3, G_3, B_3} <= { {R0 * 16'd128}, {G0 * 16'd107} , {B0 * 16'd21} };
            end
    end

//second level operation: Addition and subtraction operation
always@(posedge sys_clk or negedge sys_rst_n)
    begin
        if (sys_rst_n == 1'b0)
            begin
                Y_1  <= 16'd0;  
                Cb_1 <= 16'd0;  
                Cr_1 <= 16'd0;  
            end
        else
            begin
                Y_1  <= R_1 + G_1 + B_1;
                Cb_1 <= B_2 - R_2 - G_2 + 16'd32768;
                Cr_1 <= R_3 - G_3 - B_3 + 16'd32768;
            end
    end

//thrid level operation: bit shift operation
always@(posedge sys_clk or negedge sys_rst_n)
    begin
        if (sys_rst_n == 1'b0)
            begin
                Y_2  <= 16'd0;  
                Cb_2 <= 16'd0;  
                Cr_2 <= 16'd0;  
            end
        else
            begin
                Y_2  <= Y_1  >> 8;
                Cb_2 <= Cb_1 >> 8;
                Cr_2 <= Cr_1 >> 8;
            end
    end

assign gray_data = {Y_2 [7:0], Y_2 [7:0], Y_2 [7:0]};

always@(posedge sys_clk or negedge sys_rst_n)
    begin
        if (sys_rst_n == 1'b0)
            begin
                rgb_hsync_ack   <= 1'b0;
                rgb_hsync_ack_1 <= 1'b0;
                ycbcr_hsync     <= 1'b0;
            end
        else
            begin
                rgb_hsync_ack   <= rgb_hsync;
                rgb_hsync_ack_1 <= rgb_hsync_ack;
                ycbcr_hsync     <= ycbcr_hsync;
            end  
    end

always@(posedge sys_clk or negedge sys_rst_n)
    begin
        if (sys_rst_n == 1'b0)
            begin
                rgb_vsync_ack   <= 1'b0;
                rgb_vsync_ack_1 <= 1'b0;
                ycbcr_vsync     <= 1'b0;
            end
        else
            begin
                rgb_vsync_ack   <= rgb_vsync;
                rgb_vsync_ack_1 <= rgb_vsync_ack;
                ycbcr_vsync     <= ycbcr_vsync;
            end  
    end

always@(posedge sys_clk or negedge sys_rst_n)
    begin
        if (sys_rst_n == 1'b0)
            begin
                image_data_valid_ack   <= 1'b0;
                image_data_valid_ack_1 <= 1'b0;
                ycbcr_valid            <= 1'b0;
            end
        else
            begin
                image_data_valid_ack   <= image_data_valid;
                image_data_valid_ack_1 <= image_data_valid_ack;
                ycbcr_valid            <= image_data_valid_ack_1;
            end  
    end
endmodule