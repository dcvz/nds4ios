//
//  EmulatorViewController.swift
//  Nitrogen
//
//  Created by David Chavez on 19/03/16.
//  Copyright © 2016 Mystical. All rights reserved.
//

import UIKit
import GLKit
import PureLayout

class EmulatorViewController: UIViewController, GLKViewDelegate {

    // MARK: - Attributes (View)

    private let mainView: GLKView = GLKView.newAutoLayoutView()
    private let touchView: GLKView = GLKView.newAutoLayoutView()


    // MARK: - Attributes (Instance)

    var emulator: EmulatorCore = EmulatorCore()
    var audioCore: OEGameAudio!
    private let effect: GLKBaseEffect = GLKBaseEffect()
    private var texture: GLuint = 0

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        setupView()
        setupGL()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    // MARK: - Private Methods

    private func setupView() {
        view.backgroundColor = UIColor.whiteColor()

        mainView.tag = 44
        mainView.delegate = self
        mainView.enableSetNeedsDisplay = false
        view.addSubview(mainView)
        mainView.autoPinEdgeToSuperviewEdge(.Left)
        mainView.autoPinEdgeToSuperviewEdge(.Top)
        mainView.autoPinEdgeToSuperviewEdge(.Right)

        touchView.delegate = self
        touchView.enableSetNeedsDisplay = false
        view.addSubview(touchView)
        touchView.autoPinEdgeToSuperviewEdge(.Left, withInset: 8)
        touchView.autoPinEdge(.Top, toEdge: .Bottom, ofView: mainView, withOffset: 8)
        touchView.autoPinEdgeToSuperviewEdge(.Right, withInset: 8)
        touchView.autoMatchDimension(.Height, toDimension: .Height, ofView: mainView, withMultiplier: 0.8)
        touchView.autoPinEdgeToSuperviewEdge(.Bottom, withInset: 150)
    }

    private func setupGL() {
        let glContext = EAGLContext(API: .OpenGLES2)
        EAGLContext.setCurrentContext(glContext)
        mainView.context = glContext
        touchView.context = glContext
        setupTexture()
        setupEmulator()
    }

    private func setupTexture() {
        glGenTextures(1, &texture)
        glBindTexture(GLenum(GL_TEXTURE_2D), texture)
        glTexImage2D(GLenum(GL_TEXTURE_2D), 0, emulator.internalPixelFormat(), GLsizei(emulator.bufferSize().width), GLsizei(emulator.bufferSize().height), 0, emulator.pixelFormat(), emulator.pixelType(), emulator.videoBuffer())
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MAG_FILTER), GLfloat(GL_NEAREST))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_MIN_FILTER), GLfloat(GL_NEAREST))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_S), GLfloat(GL_CLAMP_TO_EDGE))
        glTexParameterf(GLenum(GL_TEXTURE_2D), GLenum(GL_TEXTURE_WRAP_T), GLfloat(GL_CLAMP_TO_EDGE))
    }

    private func setupEmulator() {
        let documentsDirectoryURL: NSURL! =  try! NSFileManager().URLForDirectory(.DocumentDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        let romName: String! = documentsDirectoryURL.lastPathComponent?.componentsSeparatedByString(".")[0]
        let batterySavesDirectoryPath: NSURL! = documentsDirectoryURL.URLByAppendingPathComponent("Battery States").URLByAppendingPathComponent(romName)
        let ndsFile: NSURL! = documentsDirectoryURL.URLByAppendingPathComponent("game.nds")

        do {
            try NSFileManager.defaultManager().createDirectoryAtURL(batterySavesDirectoryPath, withIntermediateDirectories: true, attributes: nil)
        } catch {}

        audioCore = OEGameAudio(core: emulator)
        audioCore.volume = 1.0
        audioCore.outputDeviceID = 0
        audioCore.startAudio()

        emulator.loadROM(ndsFile.path)
        emulator.startEmulation()
        emulator.updateFrameBlock = { [weak self] in
            self?.mainView.display()
            self?.touchView.display()
        }
    }


    // MARK: - GLKViewDelegate

    func glkView(view: GLKView, drawInRect rect: CGRect) {
        glClearColor(1.0, 1.0, 1.0, 1.0)
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))

        let screenSize: CGSize = emulator.screenRect().size
        let bufferSize: CGSize = emulator.bufferSize()

        let texWidth: Float = Float(screenSize.width / bufferSize.width)
        let texHeight: Float = Float(screenSize.height / bufferSize.height)

        var vertices: [GLKVector3] = Array<GLKVector3>(count: 8, repeatedValue: GLKVector3())
        vertices[0] = GLKVector3(v: (-1.0, -1.0,  1.0)) // Left  bottom
        vertices[1] = GLKVector3(v: ( 1.0, -1.0,  1.0)) // Right  bottom
        vertices[2] = GLKVector3(v: ( 1.0,  1.0,  1.0)) // Right  top
        vertices[3] = GLKVector3(v: (-1.0,  1.0,  1.0)) // Left  top

        var textureCoordinates: [GLKVector2] = Array<GLKVector2>(count: 8, repeatedValue: GLKVector2())
        textureCoordinates[0] = GLKVector2(v: (0.0, texHeight)) // Left bottom
        textureCoordinates[1] = GLKVector2(v: (texWidth, texHeight)) // Right bottom
        textureCoordinates[2] = GLKVector2(v: (texWidth, 0.0)) // Right top
        textureCoordinates[3] = GLKVector2(v: (0.0, 0.0)) // Left top

        let vertexIndices = [
            0, 1, 2,
            0, 2, 3
        ]

        var triangleVertices: [GLKVector3] = Array<GLKVector3>(count: 6, repeatedValue: GLKVector3())
        var triangleTexCoords: [GLKVector2] = Array<GLKVector2>(count: 6, repeatedValue: GLKVector2())
        for i in 0..<vertexIndices.count {
            triangleVertices[i] = vertices[vertexIndices[i]]
            triangleTexCoords[i] = textureCoordinates[vertexIndices[i]]
        }

        glBindTexture(GLenum(GL_TEXTURE_2D), texture)

        if view.tag == 44 {
            glTexSubImage2D(GLenum(GL_TEXTURE_2D), 0, 0, 0, GLsizei(emulator.bufferSize().width), GLsizei(emulator.bufferSize().height), emulator.pixelFormat(), emulator.pixelType(), emulator.videoBuffer())
        } else {
            glTexSubImage2D(GLenum(GL_TEXTURE_2D), 0, 0, 0, GLsizei(emulator.bufferSize().width), GLsizei(emulator.bufferSize().height), emulator.pixelFormat(), emulator.pixelType(), emulator.videoBuffer() + 256*192*4)
        }

        if texture > 0 {
            effect.texture2d0.envMode = .Replace
            effect.texture2d0.target = .Target2D
            effect.texture2d0.name = texture
            effect.texture2d0.enabled = GLboolean(1)
            effect.useConstantColor = GLboolean(1)
        }

        effect.prepareToDraw()

        glDisable(GLenum(GL_DEPTH_TEST))
        glDisable(GLenum(GL_CULL_FACE))

        glEnableVertexAttribArray(GLuint(GLKVertexAttrib.Position.rawValue))
        glVertexAttribPointer(GLuint(GLKVertexAttrib.Position.rawValue), 3, GLenum(GL_FLOAT), GLboolean(0), 0, triangleVertices)

        if texture > 0 {
            glEnableVertexAttribArray(GLuint(GLKVertexAttrib.TexCoord0.rawValue))
            glVertexAttribPointer(GLuint(GLKVertexAttrib.TexCoord0.rawValue), 2, GLenum(GL_FLOAT), GLboolean(0), 0, triangleTexCoords)
        }

        glDrawArrays(GLenum(GL_TRIANGLES), 0, 6)

        if texture > 0 {
            glDisableVertexAttribArray(GLuint(GLKVertexAttrib.TexCoord0.rawValue))
        }

        glDisableVertexAttribArray(GLuint(GLKVertexAttrib.Position.rawValue))
    }
}
