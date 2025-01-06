
import rl;
import rlgl;

const GOL_WIDTH = 768;
const MAX_BUFFERED_TRANSFERTS = 48;

struct GolUpdateCmd {
    uint x;         // x coordinate of the gol command
    uint y;         // y coordinate of the gol command
    uint w;         // width of the filled zone
    uint enabled;   // whether to enable or disable zone
}

// Game Of Life Update Commands SSBO
struct GolUpdateSSBO {
    uint count;
    GolUpdateCmd[MAX_BUFFERED_TRANSFERTS] commands;
}

fn int main(String[] args)
{
    rl::initWindow(GOL_WIDTH, GOL_WIDTH, "Raylib in C3!");
    defer rl::closeWindow();

    Vector2 resolution = { GOL_WIDTH, GOL_WIDTH };
    int brushSize = 8;

    uint golLogicShader, golLogicProgram;
    {
        ZString code = rl::loadFileText("./resources/shaders/gol.glsl")!!;
        defer rl::unloadFileText(code);
         golLogicShader= rlgl::compileShader(code, rlgl::COMPUTE_SHADER);
        golLogicProgram = rlgl::loadComputeShaderProgram(golLogicShader);
    }
    defer rlgl::unloadShaderProgram(golLogicProgram);

    uint golTransfertShader, golTransfertProgram;
    {
        ZString code = rl::loadFileText("./resources/shaders/gol_transfert.glsl")!!;
        defer rl::unloadFileText(code);
         golTransfertShader= rlgl::compileShader(code, rlgl::COMPUTE_SHADER);
        golTransfertProgram = rlgl::loadComputeShaderProgram(golTransfertShader);
    }
    defer rlgl::unloadShaderProgram(golTransfertProgram);

    rl::Shader golRenderShader = rl::loadShader(null,"./resources/shaders/gol_renderer.glsl");
    defer rl::unloadShader(golRenderShader);
    int resUniformLoc = rl::getShaderLocation(golRenderShader, "resolution");

    uint ssboA = rlgl::loadShaderBuffer(GOL_WIDTH*GOL_WIDTH*uint.sizeof, null, rlgl::DYNAMIC_COPY);
    defer rlgl::unloadShaderBuffer(ssboA);

    uint ssboB = rlgl::loadShaderBuffer(GOL_WIDTH*GOL_WIDTH*uint.sizeof, null, rlgl::DYNAMIC_COPY);
    defer rlgl::unloadShaderBuffer(ssboB);

    uint ssboTransfert = rlgl::loadShaderBuffer(GolUpdateSSBO.sizeof, null, rlgl::DYNAMIC_COPY);
    defer rlgl::unloadShaderBuffer(ssboTransfert);

    GolUpdateSSBO transfertBuffer = { 0 , {} };

    //Setup
    rl::Image whiteImage = rl::genImageColor(GOL_WIDTH, GOL_WIDTH, rl::WHITE);
    rl::Texture whiteTex = rl::loadTextureFromImage(whiteImage);
    rl::unloadImage(whiteImage);


    while (!rl::windowShouldClose())
    {
        brushSize += (int)rl::getMouseWheelMove();

        if ((rl::isMouseButtonDown(rl::MOUSE_BUTTON_LEFT) || rl::isMouseButtonDown(rl::MOUSE_BUTTON_RIGHT))
            && (transfertBuffer.count < MAX_BUFFERED_TRANSFERTS))
        {
            // Buffer a new command
            transfertBuffer.commands[transfertBuffer.count].x = rl::getMouseX() - brushSize/2;
            transfertBuffer.commands[transfertBuffer.count].y = rl::getMouseY() - brushSize/2;
            transfertBuffer.commands[transfertBuffer.count].w = brushSize;
            transfertBuffer.commands[transfertBuffer.count].enabled = (int)rl::isMouseButtonDown(rl::MOUSE_BUTTON_LEFT);
            transfertBuffer.count++;
        }
        else if (transfertBuffer.count > 0)  // Process transfert buffer
        {
            // Send SSBO buffer to GPU
            rlgl::updateShaderBuffer(ssboTransfert, &transfertBuffer, GolUpdateSSBO.sizeof, 0);

            // Process SSBO commands on GPU
            rlgl::enableShader(golTransfertProgram);
            rlgl::bindShaderBuffer(ssboA, 1);
            rlgl::bindShaderBuffer(ssboTransfert, 3);
            rlgl::computeShaderDispatch(transfertBuffer.count, 1, 1); // Each GPU unit will process a command!
            rlgl::disableShader();

            transfertBuffer.count = 0;
        }
        else
        {
            // Process game of life logic
            rlgl::enableShader(golLogicProgram);
            rlgl::bindShaderBuffer(ssboA, 1);
            rlgl::bindShaderBuffer(ssboB, 2);
            rlgl::computeShaderDispatch(GOL_WIDTH/16, GOL_WIDTH/16, 1);
            rlgl::disableShader();

            // ssboA <-> ssboB
            int temp = ssboA;
            ssboA = ssboB;
            ssboB = temp;
        }

        rlgl::bindShaderBuffer(ssboA, 1);
        rl::setShaderValue(golRenderShader, resUniformLoc, &resolution, rl::SHADER_UNIFORM_VEC2);

        rl::@drawing() {
            rl::clearBackground(rl::BLANK);
            rl::@shaderMode(golRenderShader) {
                rl::drawTexture(whiteTex,0,0, rl::WHITE);
            };

            rl::drawRectangleLines(rl::getMouseX() - brushSize/2, rl::getMouseY() - brushSize/2, brushSize, brushSize, rl::RED);
            //rl::drawText("Raylib in C3!", 190, 200, 20, rl::LIGHTGRAY);
            rl::drawText("Use Mouse wheel to increase/decrease brush size", 10, 10, 20, rl::WHITE);
            rl::drawFps(rl::getScreenWidth() - 100, 10);
        };
    }
    
    return 0;
}