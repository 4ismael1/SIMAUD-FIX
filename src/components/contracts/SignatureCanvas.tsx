import React, { useRef, useState, useEffect } from 'react';
import { motion } from 'framer-motion';
import { 
  PenTool, 
  RotateCcw, 
  Save, 
  X,
  CheckCircle,
  Download,
  Trash2
} from 'lucide-react';
import SignatureCanvasLib from 'react-signature-canvas';
import { LoadingSpinner } from '../common/LoadingSpinner';

interface SignatureCanvasProps {
  isOpen: boolean;
  onClose: () => void;
  onSave: (signatureDataUrl: string) => Promise<void>;
  signerName: string;
  contractTitle: string;
  loading?: boolean;
}

export const SignatureCanvas: React.FC<SignatureCanvasProps> = ({
  isOpen,
  onClose,
  onSave,
  signerName,
  contractTitle,
  loading = false
}) => {
  const signatureRef = useRef<SignatureCanvasLib>(null);
  const [isEmpty, setIsEmpty] = useState(true);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    if (isOpen) {
      setIsEmpty(true);
    }
  }, [isOpen]);

  const clearSignature = () => {
    signatureRef.current?.clear();
    setIsEmpty(true);
  };

  const handleSignatureEnd = () => {
    if (signatureRef.current) {
      setIsEmpty(signatureRef.current.isEmpty());
      console.log('Signature end detected, isEmpty:', signatureRef.current.isEmpty());
    }
  };

  const handleSignatureBegin = () => {
    console.log('Signature begin detected');
    setIsEmpty(false); // Assume user is drawing something
  };

  const handleSave = async () => {
    if (!signatureRef.current || isEmpty) return;

    setSaving(true);
    try {
      // Get signature as data URL with high quality
      const signatureDataUrl = signatureRef.current.toDataURL('image/png', 1.0);
      await onSave(signatureDataUrl);
    } catch (error) {
      console.error('Error saving signature:', error);
    } finally {
      setSaving(false);
    }
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 bg-gray-900 bg-opacity-75 flex items-center justify-center z-50 p-4">
      <motion.div
        initial={{ opacity: 0, scale: 0.9 }}
        animate={{ opacity: 1, scale: 1 }}
        className="bg-white rounded-xl shadow-2xl w-full max-w-4xl max-h-[95vh] overflow-hidden mx-auto"
      >
        {/* Header */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between p-4 sm:p-6 border-b border-gray-200 bg-gradient-to-r from-blue-50 to-purple-50">
          <div className="flex items-center space-x-4">
            <div className="p-3 bg-gradient-to-r from-blue-500 to-purple-600 rounded-xl">
              <PenTool className="w-6 h-6 text-white" />
            </div>
            <div className="min-w-0 flex-1">
              <h3 className="text-xl font-bold text-gray-900">Firma Digital</h3>
              <p className="text-sm text-gray-600 truncate">
                {signerName} • {contractTitle}
              </p>
            </div>
          </div>
          <button
            onClick={onClose}
            disabled={saving || loading}
            className="text-gray-400 hover:text-gray-600 p-2 rounded-lg hover:bg-gray-100 transition-colors duration-200 mt-2 sm:mt-0 self-end sm:self-auto"
          >
            <X className="w-6 h-6" />
          </button>
        </div>

        {/* Instructions */}
        <div className="p-4 sm:p-6 bg-blue-50 border-b border-blue-100">
          <div className="flex items-center space-x-3">
            <div className="p-2 bg-blue-100 rounded-lg">
              <PenTool className="w-5 h-5 text-blue-600" />
            </div>
            <div className="min-w-0 flex-1">
              <h4 className="font-semibold text-blue-900">Instrucciones de Firma</h4>
              <p className="text-xs sm:text-sm text-blue-700">
                Dibuja tu firma en el área designada usando el mouse, trackpad o pantalla táctil. 
                Asegúrate de que sea clara y legible.
              </p>
            </div>
          </div>
        </div>

        {/* Signature Area */}
        <div className="p-4 sm:p-6">
          <div className="border-2 border-dashed border-gray-300 rounded-xl p-4 bg-gray-50">
            <div className="bg-white border-2 border-gray-200 rounded-lg shadow-inner overflow-hidden">
              <SignatureCanvasLib
                ref={signatureRef}
                onBegin={handleSignatureBegin}
                onEnd={handleSignatureEnd}
                canvasProps={{
                  className: 'signature-canvas',
                  width: window.innerWidth < 768 ? 400 : 800,
                  height: 200,
                  style: {
                    width: '100%',
                    height: '200px',
                    border: 'none',
                    borderRadius: '8px'
                  }
                }}
                backgroundColor="rgba(255,255,255,1)"
                penColor="#1f2937"
                minWidth={1}
                maxWidth={2.5}
                velocityFilterWeight={0.7}
                dotSize={0.5}
              />
            </div>
            <div className="flex items-center justify-center mt-4 text-xs sm:text-sm text-gray-500">
              <PenTool className="w-4 h-4 mr-2" />
              <span>Área de Firma - {signerName}</span>
              {isEmpty && (
                <span className="ml-2 text-orange-600 font-medium">
                  (Dibuja tu firma arriba)
                </span>
              )}
            </div>
          </div>
        </div>

        {/* Legal Text */}
        <div className="px-4 sm:px-6 pb-4">
          <div className="bg-gray-50 border border-gray-200 rounded-lg p-4">
            <p className="text-xs leading-relaxed text-gray-600">
              <strong>Declaración Legal:</strong> Al firmar digitalmente este documento, acepto que:
              (1) Esta firma digital tiene la misma validez legal que una firma manuscrita,
              (2) He leído y entendido completamente el contenido del contrato,
              (3) Acepto todos los términos y condiciones establecidos en el documento,
              (4) Esta firma se realizó por mi propia voluntad sin coacción alguna.
            </p>
          </div>
        </div>

        {/* Actions */}
        <div className="flex flex-col sm:flex-row sm:items-center justify-between p-4 sm:p-6 border-t border-gray-200 bg-gray-50 space-y-3 sm:space-y-0">
          <div className="flex flex-wrap gap-2">
            <button
              onClick={clearSignature}
              disabled={isEmpty || saving || loading}
              className="flex items-center space-x-2 px-3 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-100 transition-colors duration-200 disabled:opacity-50 text-sm"
            >
              <RotateCcw className="w-4 h-4" />
              <span>Borrar</span>
            </button>
            
            {/* Debug info */}
            <div className="hidden sm:flex text-xs text-gray-500 items-center space-x-2">
              <span>Debug:</span>
              <span className={isEmpty ? 'text-red-600' : 'text-green-600'}>
                {isEmpty ? 'Vacía' : 'Con firma'}
              </span>
            </div>
          </div>
          
          <div className="flex flex-col sm:flex-row space-y-2 sm:space-y-0 sm:space-x-3 w-full sm:w-auto">
            <button
              onClick={onClose}
              disabled={saving || loading}
              className="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 font-medium hover:bg-gray-100 transition-colors duration-200 text-sm"
            >
              Cancelar
            </button>
            <button
              onClick={handleSave}
              disabled={isEmpty || saving || loading}
              className={`flex items-center justify-center space-x-2 px-4 sm:px-6 py-2 sm:py-3 rounded-lg font-bold text-white transition-all duration-200 shadow-lg text-sm sm:text-lg min-h-[44px] ${
                isEmpty || saving || loading
                  ? 'bg-gray-400 cursor-not-allowed opacity-50'
                  : 'bg-gradient-to-r from-green-500 to-green-600 hover:from-green-600 hover:to-green-700 transform hover:scale-105'
              }`}
            >
              {saving || loading ? (
                <>
                  <LoadingSpinner size="small" />
                  <span className="font-bold hidden sm:inline">Guardando firma...</span>
                  <span className="font-bold sm:hidden">Guardando...</span>
                </>
              ) : (
                <>
                  <CheckCircle className="w-5 h-5" />
                  <span className="font-bold hidden sm:inline">CONFIRMAR FIRMA</span>
                  <span className="font-bold sm:hidden">FIRMAR</span>
                </>
              )}
            </button>
          </div>
        </div>
      </motion.div>
    </div>
  );
};