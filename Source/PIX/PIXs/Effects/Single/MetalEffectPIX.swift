//
//  MetalEffectPIX.swift
//  PixelKit
//
//  Created by Hexagons on 2018-09-07.
//  Open Source - MIT License
//

import LiveValues
import RenderKit
import Metal

/// Metal Shader (Effect)
///
/// vars: pi, u, v, uv, w, h, wu, hv, input
///
/// Example:
/// ~~~~swift
/// let metalEffectPix = MetalEffectPIX(code:
///     """
///     float gamma = 0.25;
///     pix = pow(input, 1.0 / gamma);
///     """
/// )
/// metalEffectPix.input = CameraPIX()
/// ~~~~
public class MetalEffectPIX: PIXSingleEffect, NODEMetal {
    
    override open var shaderName: String { return "effectSingleMetalPIX" }
    
    // MARK: - Private Properties

    public let metalFileName = "EffectSingleMetalPIX.metal"
    
    public override var shaderNeedsAspect: Bool { return true }
    
    public var metalUniforms: [MetalUniform] { didSet { bakeFrag() } }
    
    public var code: String { didSet { bakeFrag() } }
    public var isRawCode: Bool = false
    public var metalCode: String? {
        if isRawCode { return code }
        console = nil
        do {
            return try pixelKit.render.embedMetalCode(uniforms: metalUniforms, code: code, fileName: metalFileName)
        } catch {
            pixelKit.logger.log(node: self, .error, .metal, "Metal code could not be generated.", e: error)
            return nil
        }
    }
    public var console: String?
    public var consoleCallback: ((String) -> ())?
    
    // MARK: - Property Helpers
    
    override public var liveValues: [LiveValue] {
        return metalUniforms.map({ uniform -> LiveFloat in return uniform.value })
    }
    
    public init(uniforms: [MetalUniform] = [], code: String) {
        metalUniforms = uniforms
        self.code = code
        super.init()
        name = "metalEffect"
    }
    
    required init() {
        metalUniforms = []
        code = ""
        super.init()
    }
    
    func bakeFrag() {
        console = nil
        do {
            let frag = try pixelKit.render.makeMetalFrag(shaderName, from: self)
            try makePipeline(with: frag)
        } catch {
            switch error {
            case Render.ShaderError.metalError(let codeError, let errorFrag):
                pixelKit.logger.log(node: self, .error, nil, "Metal code failed.", e: codeError)
                console = codeError.localizedDescription
                consoleCallback?(console!)
                do {
                    try makePipeline(with: errorFrag)
                } catch {
                    pixelKit.logger.log(node: self, .fatal, nil, "Metal fail failed.", e: error)
                }
            default:
                pixelKit.logger.log(node: self, .fatal, nil, "Metal bake failed.", e: error)
            }
        }
    }
    
    func makePipeline(with frag: MTLFunction) throws {
        let vtx: MTLFunction? = customVertexShaderName != nil ? try pixelKit.render.makeVertexShader(customVertexShaderName!, with: customMetalLibrary) : nil
        pipeline = try pixelKit.render.makeShaderPipeline(frag, with: vtx)
        setNeedsRender()
    }
    
}


public extension NODEOut {
    
    func _lumaToAlpha() -> MetalEffectPIX {
        let metalEffectPix = MetalEffectPIX(code:
            """
            float luma = (input.r + input.g + input.b) / 3;
            pix = float4(input.r, input.r, input.r, luma);
            """
        )
        metalEffectPix.name = "lumaToAlpha:metalEffectPix"
        metalEffectPix.input = self as? PIX & NODEOut
        return metalEffectPix
    }
    
    func _ignoreAlpha() -> MetalEffectPIX {
        let metalEffectPix = MetalEffectPIX(code:
            """
            pix = float4(input.r, input.g, input.b, 1.0);
            """
        )
        metalEffectPix.name = "ignoreAlpha:metalEffectPix"
        metalEffectPix.input = self as? PIX & NODEOut
        return metalEffectPix
    }
    
    func _premultiply() -> MetalEffectPIX {
        let metalEffectPix = MetalEffectPIX(code:
            """
            float4 c = input;
            pix = float4(c.r * c.a, c.g * c.a, c.b * c.a, c.a);
            """
        )
        metalEffectPix.name = "premultiply:metalEffectPix"
        metalEffectPix.input = self as? PIX & NODEOut
        return metalEffectPix
    }
    
}
