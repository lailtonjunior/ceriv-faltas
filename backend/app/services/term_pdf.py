import os
import logging
from datetime import datetime
from io import BytesIO
from typing import Optional, Tuple

from reportlab.lib.pagesizes import A4
from reportlab.lib import colors
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Image, Table, TableStyle
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch, cm

# Configuração de logging
logger = logging.getLogger(__name__)

# Configurações do PDF
PAGE_WIDTH, PAGE_HEIGHT = A4
MARGIN = 2.5 * cm


class TermPDFGenerator:
    """Classe para geração de PDFs de termos de adesão."""

    def __init__(self):
        """Inicializa o gerador de PDF."""
        self.styles = getSampleStyleSheet()
        
        # Adicionar estilos personalizados
        self.styles.add(
            ParagraphStyle(
                name='Title',
                parent=self.styles['Heading1'],
                fontSize=16,
                alignment=1,  # Centralizado
            )
        )
        
        self.styles.add(
            ParagraphStyle(
                name='Subtitle',
                parent=self.styles['Heading2'],
                fontSize=14,
                alignment=1,  # Centralizado
                spaceAfter=0.5 * cm,
            )
        )
        
        self.styles.add(
            ParagraphStyle(
                name='Normal_Justified',
                parent=self.styles['Normal'],
                alignment=4,  # Justificado
                firstLineIndent=0.5 * cm,
            )
        )

    def _create_header(self, doc, canvas, term_title: str):
        """
        Cria o cabeçalho do documento.
        
        Args:
            doc: Documento ReportLab
            canvas: Canvas do ReportLab
            term_title: Título do termo
        """
        canvas.saveState()
        
        # Cabeçalho
        canvas.setFont('Helvetica-Bold', 14)
        canvas.drawString(MARGIN, PAGE_HEIGHT - MARGIN, "Centro Especializado em Reabilitação - CER IV")
        
        # Linha horizontal
        canvas.setStrokeColor(colors.blue)
        canvas.line(MARGIN, PAGE_HEIGHT - MARGIN - 0.3 * cm, PAGE_WIDTH - MARGIN, PAGE_HEIGHT - MARGIN - 0.3 * cm)
        
        # Data
        canvas.setFont('Helvetica', 10)
        date_text = f"Data: {datetime.now().strftime('%d/%m/%Y')}"
        canvas.drawRightString(PAGE_WIDTH - MARGIN, PAGE_HEIGHT - MARGIN, date_text)
        
        # Título do termo
        canvas.setFont('Helvetica-Bold', 12)
        canvas.drawCentredString(PAGE_WIDTH / 2, PAGE_HEIGHT - MARGIN - 1.5 * cm, term_title)
        
        canvas.restoreState()

    def _create_footer(self, doc, canvas, page_num: int, total_pages: int):
        """
        Cria o rodapé do documento.
        
        Args:
            doc: Documento ReportLab
            canvas: Canvas do ReportLab
            page_num: Número da página atual
            total_pages: Total de páginas
        """
        canvas.saveState()
        
        # Linha horizontal
        canvas.setStrokeColor(colors.blue)
        canvas.line(MARGIN, MARGIN + 1 * cm, PAGE_WIDTH - MARGIN, MARGIN + 1 * cm)
        
        # Informações de contato
        canvas.setFont('Helvetica', 8)
        contact_text = "Centro Especializado em Reabilitação - CER IV | contato@ceriv.org.br | (00) 1234-5678"
        canvas.drawCentredString(PAGE_WIDTH / 2, MARGIN + 0.7 * cm, contact_text)
        
        # Número de página
        canvas.setFont('Helvetica', 8)
        page_text = f"Página {page_num} de {total_pages}"
        canvas.drawRightString(PAGE_WIDTH - MARGIN, MARGIN + 0.7 * cm, page_text)
        
        canvas.restoreState()

    def generate_term_pdf(
        self,
        term_title: str,
        term_content: str,
        patient_name: str,
        patient_cpf: str,
        patient_signature_path: Optional[str] = None,
        patient_signature_text: str = "",
        guardian_name: Optional[str] = None,
        guardian_cpf: Optional[str] = None,
        guardian_signature_path: Optional[str] = None,
        guardian_signature_text: Optional[str] = None,
        term_version: str = "1.0",
    ) -> BytesIO:
        """
        Gera um PDF com o termo de adesão.
        
        Args:
            term_title: Título do termo
            term_content: Conteúdo do termo em texto
            patient_name: Nome do paciente
            patient_cpf: CPF do paciente
            patient_signature_path: Caminho para a imagem da assinatura do paciente
            patient_signature_text: Assinatura textual do paciente
            guardian_name: Nome do responsável (se menor)
            guardian_cpf: CPF do responsável (se menor)
            guardian_signature_path: Caminho para a imagem da assinatura do responsável
            guardian_signature_text: Assinatura textual do responsável
            term_version: Versão do termo
            
        Returns:
            BytesIO contendo o PDF gerado
        """
        buffer = BytesIO()
        
        # Configurar o documento
        doc = SimpleDocTemplate(
            buffer, 
            pagesize=A4, 
            leftMargin=MARGIN, 
            rightMargin=MARGIN, 
            topMargin=MARGIN + 2 * cm, 
            bottomMargin=MARGIN + 1.5 * cm
        )
        
        # Lista de elementos a serem adicionados ao documento
        elements = []
        
        # Adicionar conteúdo do termo
        for paragraph in term_content.split('\n\n'):
            if paragraph.strip():
                p = Paragraph(paragraph, self.styles['Normal_Justified'])
                elements.append(p)
                elements.append(Spacer(1, 0.3 * cm))
        
        elements.append(Spacer(1, 1 * cm))
        
        # Tabela de informações do paciente
        patient_data = [
            ['DADOS DO PACIENTE', ''],
            ['Nome completo:', patient_name],
            ['CPF:', patient_cpf],
        ]
        
        patient_table = Table(patient_data, colWidths=[4 * cm, 10 * cm])
        patient_table.setStyle(TableStyle([
            ('BACKGROUND', (0, 0), (1, 0), colors.lightgrey),
            ('TEXTCOLOR', (0, 0), (1, 0), colors.black),
            ('ALIGN', (0, 0), (1, 0), 'CENTER'),
            ('FONTNAME', (0, 0), (1, 0), 'Helvetica-Bold'),
            ('FONTSIZE', (0, 0), (1, 0), 12),
            ('BOTTOMPADDING', (0, 0), (1, 0), 5),
            ('BACKGROUND', (0, 1), (1, -1), colors.white),
            ('GRID', (0, 0), (1, -1), 0.5, colors.grey),
            ('SPAN', (0, 0), (1, 0)),
        ]))
        
        elements.append(patient_table)
        elements.append(Spacer(1, 0.5 * cm))
        
        # Informações do responsável (se houver)
        if guardian_name and guardian_cpf:
            guardian_data = [
                ['DADOS DO RESPONSÁVEL', ''],
                ['Nome completo:', guardian_name],
                ['CPF:', guardian_cpf],
            ]
            
            guardian_table = Table(guardian_data, colWidths=[4 * cm, 10 * cm])
            guardian_table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (1, 0), colors.lightgrey),
                ('TEXTCOLOR', (0, 0), (1, 0), colors.black),
                ('ALIGN', (0, 0), (1, 0), 'CENTER'),
                ('FONTNAME', (0, 0), (1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (1, 0), 12),
                ('BOTTOMPADDING', (0, 0), (1, 0), 5),
                ('BACKGROUND', (0, 1), (1, -1), colors.white),
                ('GRID', (0, 0), (1, -1), 0.5, colors.grey),
                ('SPAN', (0, 0), (1, 0)),
            ]))
            
            elements.append(guardian_table)
            elements.append(Spacer(1, 0.5 * cm))
        
        # Espaço para assinatura do paciente
        elements.append(Paragraph("Assinatura do Paciente:", self.styles['Heading4']))
        
        if patient_signature_path and os.path.exists(patient_signature_path):
            # Adicionar imagem da assinatura
            try:
                signature_img = Image(patient_signature_path, width=8 * cm, height=3 * cm)
                elements.append(signature_img)
            except Exception as e:
                logger.error(f"Erro ao carregar imagem de assinatura: {e}")
                elements.append(Paragraph("Não foi possível carregar a imagem da assinatura.", self.styles['Normal']))
        
        # Adicionar assinatura por extenso
        elements.append(Paragraph(f"Assinado por extenso: {patient_signature_text}", self.styles['Normal']))
        elements.append(Spacer(1, 0.5 * cm))
        
        # Espaço para assinatura do responsável (se houver)
        if guardian_name and guardian_signature_text:
            elements.append(Paragraph("Assinatura do Responsável:", self.styles['Heading4']))
            
            if guardian_signature_path and os.path.exists(guardian_signature_path):
                # Adicionar imagem da assinatura do responsável
                try:
                    guardian_sig_img = Image(guardian_signature_path, width=8 * cm, height=3 * cm)
                    elements.append(guardian_sig_img)
                except Exception as e:
                    logger.error(f"Erro ao carregar imagem de assinatura do responsável: {e}")
                    elements.append(Paragraph("Não foi possível carregar a imagem da assinatura.", self.styles['Normal']))
            
            # Adicionar assinatura por extenso do responsável
            elements.append(Paragraph(f"Assinado por extenso: {guardian_signature_text}", self.styles['Normal']))
            elements.append(Spacer(1, 0.5 * cm))
        
        # Adicionar informações da versão do termo
        elements.append(Spacer(1, 1 * cm))
        version_text = f"Versão do termo: {term_version} | Data de aceitação: {datetime.now().strftime('%d/%m/%Y às %H:%M')}"
        elements.append(Paragraph(version_text, self.styles['Italic']))
        
        # Construir o documento
        doc.build(
            elements,
            onFirstPage=lambda canvas, doc: self._create_header(doc, canvas, term_title),
            onLaterPages=lambda canvas, doc: self._create_header(doc, canvas, term_title),
            canvasmaker=self._page_counter
        )
        
        buffer.seek(0)
        return buffer

    def _page_counter(self, canvas):
        """
        Classe interna para contar páginas e adicionar o rodapé.
        
        Args:
            canvas: Canvas do ReportLab
        """
        class PageCounter(canvas.__class__):
            def __init__(self, *args, **kwargs):
                super().__init__(*args, **kwargs)
                self._saved_page_states = []
                self._page_count = 0
                
            def showPage(self):
                self._saved_page_states.append(dict(self.__dict__))
                self._page_count += 1
                super().showPage()
                
            def save(self):
                total_pages = self._page_count
                for page_num, page_state in enumerate(self._saved_page_states, 1):
                    self.__dict__.update(page_state)
                    self.draw_page_footer(page_num, total_pages)
                    super().showPage()
                    
                super().save()
                
            def draw_page_footer(self, page_num, total_pages):
                # Chama o método de rodapé da classe principal
                TermPDFGenerator()._create_footer(None, self, page_num, total_pages)
                
        return PageCounter


# Função de conveniência para uso direto
def generate_term_pdf(
    term_title: str,
    term_content: str,
    patient_name: str,
    patient_cpf: str,
    patient_signature_path: Optional[str] = None,
    patient_signature_text: str = "",
    guardian_name: Optional[str] = None,
    guardian_cpf: Optional[str] = None,
    guardian_signature_path: Optional[str] = None,
    guardian_signature_text: Optional[str] = None,
    term_version: str = "1.0",
) -> BytesIO:
    """
    Função wrapper para gerar PDF de termo de adesão.
    """
    generator = TermPDFGenerator()
    return generator.generate_term_pdf(
        term_title=term_title,
        term_content=term_content,
        patient_name=patient_name,
        patient_cpf=patient_cpf,
        patient_signature_path=patient_signature_path,
        patient_signature_text=patient_signature_text,
        guardian_name=guardian_name,
        guardian_cpf=guardian_cpf,
        guardian_signature_path=guardian_signature_path,
        guardian_signature_text=guardian_signature_text,
        term_version=term_version,
    )